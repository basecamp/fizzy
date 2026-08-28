class Oauth::TokensController < Oauth::BaseController
  allow_unauthenticated_access
  skip_forgery_protection

  rate_limit to: 20, within: 1.minute, only: :create, with: :oauth_rate_limit_exceeded

  before_action :validate_grant_type

  with_options if: :authorization_code_grant? do
    before_action :set_auth_code
    before_action :set_client
    before_action :validate_pkce
    before_action :validate_redirect_uri
    before_action :set_identity
  end

  with_options unless: :authorization_code_grant? do
    before_action :set_refreshable_access_token
    before_action :validate_refresh_client
  end

  def create
    if authorization_code_grant?
      granted = @auth_code.scope.to_s.split
      permission = granted.include?("write") ? "write" : "read"
      access_token = @identity.access_tokens.create! oauth_client: @client, permission: permission

      render json: token_response(access_token, scope: granted.join(" "))
    else
      @access_token.refresh!

      render json: token_response(@access_token)
    end
  end

  private
    def authorization_code_grant?
      params[:grant_type] == "authorization_code"
    end

    def validate_grant_type
      unless params[:grant_type].in?(%w[ authorization_code refresh_token ])
        oauth_error "unsupported_grant_type", "Only authorization_code and refresh_token grants are supported"
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

    def set_refreshable_access_token
      unless params[:refresh_token].present? &&
          @access_token = Identity::AccessToken.oauth.find_by(refresh_token: params[:refresh_token])
        oauth_error "invalid_grant", "Invalid refresh token"
      end
    end

    def validate_refresh_client
      unless @access_token.oauth_client.client_id == params[:client_id]
        oauth_error "invalid_grant", "Refresh token was not issued to this client"
      end
    end

    def token_response(access_token, scope: nil)
      {
        access_token: access_token.token,
        token_type: "Bearer",
        expires_in: access_token.expires_in,
        refresh_token: access_token.refresh_token,
        scope: scope
      }.compact
    end
end
