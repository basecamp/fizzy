class Oauth::TokensController < Oauth::BaseController
  allow_unauthenticated_access
  skip_forgery_protection

  rate_limit to: 20, within: 1.minute, only: :create, with: :oauth_rate_limit_exceeded

  before_action :require_issuance_enabled
  before_action :validate_grant_type

  with_options if: :authorization_code_grant? do
    before_action :require_params
    before_action :set_auth_code
    before_action :set_client
    before_action :validate_client_id
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
      granted = Oauth.canonical_scope(@auth_code.scope)
      permission = granted.split.include?("write") ? "write" : "read"

      if access_token = @identity.access_tokens.redeem(@auth_code, oauth_client: @client, permission: permission)
        render json: token_response(access_token, scope: granted)
      else
        oauth_error "invalid_grant", "Authorization code already used"
      end
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
      if params[:grant_type].blank?
        oauth_error "invalid_request", "Missing required parameter: grant_type"
      elsif !params[:grant_type].in?(%w[ authorization_code refresh_token ])
        oauth_error "unsupported_grant_type", "Only authorization_code and refresh_token grants are supported"
      end
    end

    # A missing parameter is a malformed request (invalid_request), not a dead
    # grant (invalid_grant), which a client would act on by discarding it.
    # client_id is required of every client: none authenticates by header.
    # Each is a single string; an array or object from a JSON body or a
    # name[] form field is just as malformed, and must not reach a lookup.
    def require_params
      if (missing = %w[ code code_verifier redirect_uri client_id ].reject { |name| string_param?(name) }).any?
        oauth_error "invalid_request", "Missing or malformed parameter: #{missing.to_sentence}"
      end
    end

    def string_param?(name)
      params[name].is_a?(String) && params[name].present?
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
