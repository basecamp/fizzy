class Oauth::AuthorizationsController < Oauth::BaseController
  before_action :save_oauth_return_url
  before_action :require_authentication

  before_action :set_client
  before_action :validate_redirect_uri
  before_action :validate_response_type
  before_action :validate_pkce
  before_action :validate_scope
  before_action :validate_state

  def new
    @scope = params[:scope].presence || "read"
    @redirect_uri = params[:redirect_uri]
    @state = params[:state]
    @code_challenge = params[:code_challenge]
  end

  def create
    if params[:error] == "access_denied"
      redirect_to error_redirect_uri("access_denied", "User denied the request"), allow_other_host: true
    else
      code = Oauth::AuthorizationCode.generate \
        client_id: @client.client_id,
        identity_id: Current.identity.id,
        code_challenge: params[:code_challenge],
        redirect_uri: params[:redirect_uri],
        scope: params[:scope].presence || "read"

      redirect_to success_redirect_uri(code), allow_other_host: true
    end
  end

  private
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
        state: params[:state].presence
    end

    def error_redirect_uri(error, description)
      build_redirect_uri params[:redirect_uri],
        error: error,
        error_description: description,
        state: params[:state].presence
    end

    def build_redirect_uri(base, **query_params)
      uri = URI.parse(base)
      query = URI.decode_www_form(uri.query || "")
      query_params.compact.each { |k, v| query << [ k.to_s, v ] }
      uri.query = URI.encode_www_form(query)
      uri.to_s
    end
end
