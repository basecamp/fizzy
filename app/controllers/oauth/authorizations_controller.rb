class Oauth::AuthorizationsController < Oauth::BaseController
  FORM_ACTION_ORIGIN = %r{\Ahttps?://[a-z0-9.-]+(:\d+)?\z}i
  FORM_ACTION_SCHEME = /\A[a-z][a-z0-9+.-]*\z/i
  STATE_MAXIMUM_LENGTH = 2048
  # An S256 challenge is the unpadded base64url SHA-256 of the verifier: 43 characters (RFC 7636 §4.2).
  S256_CODE_CHALLENGE = /\A[A-Za-z0-9_-]{43}\z/
  RETURN_URL_MAXIMUM_LENGTH = 2000
  # Read to find the client and the redirect target, so refused before either.
  LOOKUP_PARAMETERS = %w[ client_id redirect_uri ]

  # Browsers apply form-action to every hop of a form submission, redirects
  # included, so the app-wide form-action 'self' would block the consent POST's
  # redirect to the client. Allow just this request's validated redirect target.
  content_security_policy if: -> { request.content_security_policy } do |policy|
    policy.form_action :self, -> { validated_redirect_form_action_source }
  end

  # Gated ahead of sign-in so a dark server never asks anyone to sign in for
  # it. A denial is never gated: it only tells the client no.
  before_action :require_issuance_enabled, unless: :denial?
  before_action :require_single_valued_parameters
  before_action :save_oauth_return_url
  before_action :require_authentication
  disallow_oauth_grants

  before_action :require_admitted_identity, unless: :denial?

  before_action :set_client
  before_action :validate_redirect_uri
  before_action :validate_single_valued_parameters
  before_action :validate_response_type
  before_action :validate_pkce
  before_action :validate_scope
  before_action :validate_state
  before_action :set_audience
  before_action :set_accounts, if: :audienced?, unless: :denial?
  before_action :set_account, if: :audienced?, unless: :denial?, only: :create

  def new
    @scope = Oauth.canonical_scope(params[:scope].presence || "read")
    @redirect_uri = params[:redirect_uri]
    @state = params[:state]
    @code_challenge = params[:code_challenge]
    @resource = @audience

    record_consent "shown"
  end

  def create
    if denial?
      record_consent "denied"
      redirect_to error_redirect_uri("access_denied", "User denied the request"), allow_other_host: true
    # Consent is use, so it restarts a self-registered client's retention
    # period: the sweep (Oauth::Client.cleanup) mustn't remove the client while
    # the code it is about to receive is still redeemable. A touch that finds no
    # row means the sweep got there first, and a code would be dead on arrival.
    elsif @client.touch
      code = Oauth::AuthorizationCode.generate \
        client_id: @client.client_id,
        identity_id: Current.identity.id,
        code_challenge: params[:code_challenge],
        redirect_uri: params[:redirect_uri],
        scope: Oauth.canonical_scope(params[:scope].presence || "read"),
        audience: @audience,
        account_id: @account&.id

      record_consent "approved"
      Oauth::Audit.record "code.issued", client: @client, identity_id: Current.identity.id, actor: "user"
      redirect_to success_redirect_uri(code), allow_other_host: true
    else
      render_error "invalid_request", "Unknown client"
    end
  end

  private
    def record_consent(outcome)
      Oauth::Audit.record "consent.#{outcome}", client: @client, identity_id: Current.identity.id, actor: "user"
    end

    def denial?
      request.post? && params[:error] == "access_denied"
    end

    # While OAuth is staff only, nobody else is asked to consent. They're told
    # why, rather than bounced back to an app that can't say.
    def require_admitted_identity
      unless Oauth::Availability.admits?(Current.identity)
        render :staff_only, status: :forbidden
      end
    end

    # Runs before authentication, so a person already signed in is told apart
    # by their session cookie. The URL goes into the cookie-stored session,
    # which overflows (a 500) past 4KB once encrypted, so a request too long to
    # keep isn't kept: the person signs in and starts again from the app.
    def save_oauth_return_url
      if request.get? && !find_session_by_cookie && request.url.bytesize <= RETURN_URL_MAXIMUM_LENGTH
        session[:return_to_after_authenticating] = request.url
      end
    end

    # client_id is a single string by now (require_single_valued_parameters).
    # A metadata document client is reached only through its URL, so the
    # switch, the exact comparison and the refresh all apply to it. A client
    # not registered for the code grant, like the personal access token
    # issuer, has nothing to authorize here.
    def set_client
      @client = if Oauth::ClientMetadata::Url.url_shaped?(params[:client_id])
        metadata_document_client
      else
        Oauth::Client.find_by(client_id: params[:client_id]).then { |client| client unless client&.metadata_document? }
      end

      unless performed?
        # There's no client to send the browser back to, so the person is told here.
        if @client.nil?
          render_error "invalid_request", "Unknown client"
        elsif !@client.allows_grant_type?("authorization_code")
          oauth_error "unauthorized_client", "Client may not use the authorization code grant"
        end
      end
    end

    # A URL client_id names its metadata document (Oauth::ClientMetadata).
    # Resolved without writing on GET, which reads from a replica, and persisted
    # on the authorization POST, before a code is minted. Off, every URL client_id
    # is an unknown client, provisioned or not.
    def metadata_document_client
      if denial?
        metadata_document_client_for_denial
      elsif Oauth::Availability.metadata_documents_enabled?(params[:client_id])
        resolution = Oauth::ClientMetadata::Resolver.new(params[:client_id], requester: Current.identity).resolve(persist: persist_metadata_document?)
        resolution.client || refuse_metadata_document(resolution)
      end
    end

    def persist_metadata_document?
      request.post?
    end

    # A denial never registers a client, and stays reachable while metadata
    # documents are off: the stored row answers when it allows the redirect.
    # Otherwise (no row, or a stale one the consent screen saw past) the
    # document is read again, without persisting it.
    def metadata_document_client_for_denial
      row = Oauth::Client.find_presented(params[:client_id])
      row = nil unless row&.metadata_document?

      if (row.nil? || !row.allows_redirect?(params[:redirect_uri])) && Oauth::Availability.metadata_documents_enabled?(params[:client_id])
        Oauth::ClientMetadata::Resolver.resolve_for_read(params[:client_id], requester: Current.identity).client || row
      else
        row
      end
    end

    # The draft's answer to a document that can't be fetched or doesn't validate:
    # refuse, rather than authorize against a document we can't see. Server
    # pressure is a 503 to retry; anything else reads like an unknown client.
    def refuse_metadata_document(resolution)
      case resolution.outcome
      when :fetch_failed, :invalid_document, :throttled
        oauth_error "invalid_client_metadata", resolution.error_description
      when :overloaded
        response.headers["Retry-After"] = "5"
        oauth_error "temporarily_unavailable", resolution.error_description, status: :service_unavailable
      end

      nil
    end

    def validate_redirect_uri
      unless performed? || @client.allows_redirect?(params[:redirect_uri])
        redirect_with_error "invalid_request", "Invalid redirect_uri"
      end
    end

    def validate_response_type
      unless performed? || params[:response_type] == "code"
        redirect_with_error "unsupported_response_type", "Only 'code' response_type is supported"
      end
    end

    def validate_pkce
      unless performed? || params[:code_challenge].present?
        redirect_with_error "invalid_request", "code_challenge is required"
      end

      unless performed? || params[:code_challenge].is_a?(String) && params[:code_challenge].match?(S256_CODE_CHALLENGE)
        redirect_with_error "invalid_request", "code_challenge must be an S256 challenge"
      end

      unless performed? || params[:code_challenge_method] == "S256"
        redirect_with_error "invalid_request", "code_challenge_method must be S256"
      end
    end

    def validate_scope
      unless performed? || @client.allows_scope?(params[:scope].presence || "read")
        redirect_with_error "invalid_scope", "Requested scope is not allowed"
      end
    end

    # state is optional: PKCE is the CSRF defence (OAuth 2.1 §7.5.1), so a
    # client that doesn't send it isn't refused. One that does gets it back
    # exactly, and it must be a single string of bounded length, since it is
    # carried through the consent form and into the redirect.
    def validate_state
      unless performed? || valid_state?
        redirect_with_error "invalid_request", "state must be a string of at most #{STATE_MAXIMUM_LENGTH} characters"
      end
    end

    # A grant for the hosted MCP server is audienced to it (RFC 8707), and so
    # bound to one account. A resource naming Fizzy's own API, or none, keeps
    # the grant identity-wide, as every grant has been.
    def set_audience
      unless performed?
        if !single_resource?
          redirect_with_error "invalid_target", "Only one resource indicator is supported"
        elsif Oauth.mcp_resource?(resource_param)
          @audience = resource_param
        elsif resource_param.present? && !service_resource?(resource_param)
          redirect_with_error "invalid_target", "Unknown resource"
        end
      end
    end

    def audienced?
      @audience.present?
    end

    # An audienced grant reaches one account, which the person picks at consent
    # from the active accounts they belong to.
    def set_accounts
      unless performed?
        @accounts = Current.identity.users_with_active_accounts.map(&:account).sort_by { |account| account.name.to_s.downcase }

        if @accounts.empty?
          redirect_with_error "access_denied", "You have no account to connect"
        end
      end
    end

    def set_account
      unless performed?
        @account = @accounts.find { |account| account.id == params[:account_id] }

        unless @account
          render_error "invalid_request", "Choose an account to connect"
        end
      end
    end

    def valid_state?
      params[:state].nil? || (params[:state].is_a?(String) && params[:state].length <= STATE_MAXIMUM_LENGTH)
    end

    # Errors are found before the user sees the consent screen, so they only
    # redirect to a vetted target; Deny redirects anywhere allowed, since the
    # consent screen has named the host by then.
    def redirect_with_error(error, description)
      if params[:redirect_uri].present? && @client&.allows_redirect?(params[:redirect_uri]) && @client.vetted_redirect?(params[:redirect_uri])
        redirect_to error_redirect_uri(error, description), allow_other_host: true
      else
        render_error error, description
      end
    end

    def render_error(error, description)
      @error = error
      @error_description = description
      render :error, status: :bad_request
    end

    def success_redirect_uri(code)
      build_redirect_uri params[:redirect_uri],
        code: code,
        state: params[:state].presence,
        iss: oauth_issuer
    end

    def error_redirect_uri(error, description)
      build_redirect_uri params[:redirect_uri],
        error: error,
        error_description: description,
        state: params[:state].presence,
        iss: oauth_issuer
    end

    # A CSP source naming the validated redirect origin, port included, since a
    # loopback client may present any port (RFC 8252 §7.3). CSP host-sources
    # can't express IPv6 literals, and a registered native redirect has no
    # host, so those get their bare scheme. Nothing outside these shapes is
    # written into the header.
    def validated_redirect_form_action_source
      if @client&.allows_redirect?(params[:redirect_uri])
        uri = URI.parse(params[:redirect_uri])
        origin = "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless uri.port == uri.default_port}"

        if origin.match?(FORM_ACTION_ORIGIN)
          origin
        elsif uri.scheme.to_s.match?(FORM_ACTION_SCHEME)
          "#{uri.scheme}:"
        end
      end
    rescue URI::InvalidURIError
      nil
    end

    # client_id and redirect_uri are refused before the client is looked up,
    # and shown here, never redirected: a malformed redirect_uri is exactly the
    # one that can't be validated.
    def require_single_valued_parameters
      if (malformed = malformed_parameter_names & LOOKUP_PARAMETERS).any?
        render_error "invalid_request", malformed_parameters_description(malformed)
      end
    end

    # The rest are refused once the redirect target is known, so they go back
    # to a vetted client like any other error.
    def validate_single_valued_parameters
      malformed = malformed_parameter_names

      if !performed? && malformed.any?
        redirect_with_error "invalid_request", malformed_parameters_description(malformed)
      end
    end

    def build_redirect_uri(base, **query_params)
      uri = URI.parse(base)
      query = URI.decode_www_form(uri.query || "")
      query_params.compact.each { |k, v| query << [ k.to_s, v ] }
      uri.query = URI.encode_www_form(query)
      uri.to_s
    end
end
