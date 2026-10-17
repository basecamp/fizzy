class Oauth::AuthorizationsController < Oauth::BaseController
  FORM_ACTION_ORIGIN = %r{\Ahttps?://[a-z0-9.-]+(:\d+)?\z}i
  FORM_ACTION_SCHEME = /\A[a-z][a-z0-9+.-]*\z/i
  STATE_MAXIMUM_LENGTH = 2048
  # An S256 challenge is the unpadded base64url SHA-256 of the verifier: 43 characters (RFC 7636 §4.2).
  S256_CODE_CHALLENGE = /\A[A-Za-z0-9_-]{43}\z/
  RETURN_URL_MAXIMUM_LENGTH = 2000

  # Browsers apply form-action to every hop of a form submission, redirects
  # included, so the app-wide form-action 'self' would block the consent POST's
  # redirect to the client. Allow just this request's validated redirect target.
  content_security_policy if: -> { request.content_security_policy } do |policy|
    policy.form_action :self, -> { validated_redirect_form_action_source }
  end

  # Gated ahead of sign-in so a dark server never asks anyone to sign in for
  # it. A denial is never gated: it only tells the client no.
  before_action :require_issuance_enabled, unless: :denial?
  before_action :save_oauth_return_url
  before_action :require_authentication
  disallow_oauth_grants

  before_action :set_client
  before_action :validate_redirect_uri
  before_action :validate_response_type
  before_action :validate_pkce
  before_action :validate_scope
  before_action :validate_state

  def new
    @scope = Oauth.canonical_scope(params[:scope].presence || "read")
    @redirect_uri = params[:redirect_uri]
    @state = params[:state]
    @code_challenge = params[:code_challenge]
  end

  def create
    if denial?
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
        scope: Oauth.canonical_scope(params[:scope].presence || "read")

      redirect_to success_redirect_uri(code), allow_other_host: true
    else
      oauth_error "invalid_request", "Unknown client"
    end
  end

  private
    def denial?
      request.post? && params[:error] == "access_denied"
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

    def set_client
      @client = Oauth::Client.find_by(client_id: params[:client_id])
      oauth_error("invalid_request", "Unknown client") unless @client
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
        @error = error
        @error_description = description
        render :error, status: :bad_request
      end
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

    def build_redirect_uri(base, **query_params)
      uri = URI.parse(base)
      query = URI.decode_www_form(uri.query || "")
      query_params.compact.each { |k, v| query << [ k.to_s, v ] }
      uri.query = URI.encode_www_form(query)
      uri.to_s
    end
end
