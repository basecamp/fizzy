class Oauth::AuthorizationsController < Oauth::BaseController
  FORM_ACTION_ORIGIN = %r{\Ahttps?://[a-z0-9.-]+(:\d+)?\z}i
  FORM_ACTION_SCHEME = /\A[a-z][a-z0-9+.-]*\z/i

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
    else
      code = Oauth::AuthorizationCode.generate \
        client_id: @client.client_id,
        identity_id: Current.identity.id,
        code_challenge: params[:code_challenge],
        redirect_uri: params[:redirect_uri],
        scope: Oauth.canonical_scope(params[:scope].presence || "read")

      redirect_to success_redirect_uri(code), allow_other_host: true
    end
  end

  private
    def denial?
      request.post? && params[:error] == "access_denied"
    end

    def save_oauth_return_url
      session[:return_to_after_authenticating] = request.url if request.get? && !authenticated?
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

      unless performed? || params[:code_challenge_method] == "S256"
        redirect_with_error "invalid_request", "code_challenge_method must be S256"
      end
    end

    def validate_scope
      unless performed? || @client.allows_scope?(params[:scope].presence || "read")
        redirect_with_error "invalid_scope", "Requested scope is not allowed"
      end
    end

    def validate_state
      unless performed? || params[:state].present?
        redirect_with_error "invalid_request", "state is required"
      end
    end

    def redirect_with_error(error, description)
      if params[:redirect_uri].present? && @client&.allows_redirect?(params[:redirect_uri])
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
