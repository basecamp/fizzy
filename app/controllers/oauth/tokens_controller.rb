class Oauth::TokensController < Oauth::BaseController
  allow_unauthenticated_access
  skip_forgery_protection

  rate_limit to: 20, within: 1.minute, only: :create, with: :oauth_rate_limit_exceeded

  before_action :validate_grant_type
  before_action :require_params
  before_action :set_auth_code
  before_action :set_client
  before_action :validate_client_id
  before_action :validate_pkce
  before_action :validate_redirect_uri
  before_action :set_identity

  def create
    granted = @auth_code.scope.to_s.split
    permission = granted.include?("write") ? "write" : "read"

    if access_token = @identity.access_tokens.redeem(@auth_code, oauth_client: @client, permission: permission)
      render json: {
        access_token: access_token.token,
        token_type: "Bearer",
        scope: granted.join(" ")
      }
    else
      oauth_error "invalid_grant", "Authorization code already used"
    end
  end

  private
    def validate_grant_type
      if params[:grant_type].blank?
        oauth_error "invalid_request", "Missing required parameter: grant_type"
      elsif params[:grant_type] != "authorization_code"
        oauth_error "unsupported_grant_type", "Only authorization_code grant is supported"
      end
    end

    # A missing parameter is a malformed request (invalid_request), not a dead
    # grant (invalid_grant), which a client would act on by discarding it.
    # client_id is required of every client: none authenticates by header.
    def require_params
      if (missing = %w[ code code_verifier redirect_uri client_id ].select { |name| params[name].blank? }).any?
        oauth_error "invalid_request", "Missing required parameter: #{missing.to_sentence}"
      end
    end

    def set_auth_code
      unless @auth_code = Oauth::AuthorizationCode.parse(params[:code])
        oauth_error "invalid_grant", "Invalid or expired authorization code"
      end
    end

    def set_client
      unless @client = Oauth::Client.find_by(client_id: @auth_code.client_id)
        oauth_error "invalid_grant", "Unknown client"
      end
    end

    # RFC 6749 §4.1.3: the code must have been issued to the client_id in the request.
    def validate_client_id
      unless params[:client_id] == @client.client_id
        oauth_error "invalid_grant", "Authorization code was not issued to this client"
      end
    end

    def validate_pkce
      unless Oauth::AuthorizationCode.valid_pkce?(@auth_code, params[:code_verifier])
        oauth_error "invalid_grant", "PKCE verification failed"
      end
    end

    def validate_redirect_uri
      unless @auth_code.redirect_uri == params[:redirect_uri]
        oauth_error "invalid_grant", "redirect_uri mismatch"
      end
    end

    def set_identity
      unless @identity = Identity.find_by(id: @auth_code.identity_id)
        oauth_error "invalid_grant", "Identity not found"
      end
    end
end
