class Oauth::TokensController < Oauth::BaseController
  include Oauth::ClientAuthentication

  allow_unauthenticated_access
  skip_forgery_protection

  # A before_action, not after: a halted callback chain skips after_actions,
  # and error responses must not be cached either (RFC 6749 §5.1, §5.2).
  before_action :prevent_caching

  rate_limit to: 20, within: 1.minute, only: :create, with: :oauth_rate_limit_exceeded

  before_action :require_issuance_enabled
  before_action :validate_grant_type

  # Authenticate the client the request names before looking anything up about
  # the grant: a confidential client that fails auth must see invalid_client,
  # not an invalid_grant it could misread as a revoked grant and discard, and
  # the answer must not depend on whether the code or refresh token is live,
  # or it tells whoever holds one without the secret.
  before_action :authenticate_client
  before_action :require_params

  with_options if: :authorization_code_grant? do
    before_action :set_auth_code
    before_action :set_client
  end

  before_action :set_refreshable_access_token, unless: :authorization_code_grant?
  before_action :validate_client_id

  with_options if: :authorization_code_grant? do
    before_action :validate_pkce
    before_action :validate_redirect_uri
    before_action :set_identity
  end

  before_action :set_refresh_scope, unless: :authorization_code_grant?

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
      if @access_token.refresh(permission: @refresh_permission)
        render json: token_response(@access_token, scope: Oauth.canonical_scope(@access_token.permission))
      else
        oauth_error "invalid_grant", "Invalid refresh token"
      end
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
    # client_id is required of every client, in the body unless a Basic
    # header carries it.
    # Each is a single string; an array or object from a JSON body or a
    # name[] form field is just as malformed, and must not reach a lookup.
    def require_params
      if (missing = required_params.reject { |name| string_param?(name) }).any?
        oauth_error "invalid_request", "Missing or malformed parameter: #{missing.to_sentence}"
      end
    end

    def required_params
      (authorization_code_grant? ? %w[ code code_verifier redirect_uri ] : %w[ refresh_token ]) + (client_secret_basic? ? [] : %w[ client_id ])
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
      unless @access_token = Identity::AccessToken.oauth.find_by(refresh_token: params[:refresh_token])
        oauth_error "invalid_grant", "Invalid refresh token"
      end
    end

    # The code or refresh token must have been issued to the client_id in the
    # request (RFC 6749 §4.1.3, §6).
    # One issued to another client gets the same answer as a dead one, so
    # naming a public client tells nobody whether someone else's grant is live.
    def validate_client_id
      unless oauth_client_id == (@client || @access_token.oauth_client).client_id
        oauth_error "invalid_grant", authorization_code_grant? ? "Invalid or expired authorization code" : "Invalid refresh token"
      end
    end

    # A refresh request may narrow scope but never widen it (RFC 6749 §6). An
    # omitted scope keeps the original grant; a requested subset narrows the
    # rotated token; anything beyond the grant is invalid_scope. Only an absent
    # parameter means "keep the grant" — a blank one, or a JSON null, names no
    # scope, and the empty scope list below rejects it, since no scope-token is
    # a malformed scope (RFC 6749 §3.3), not a request for the full grant.
    def set_refresh_scope
      granted = granted_scopes(@access_token.permission)
      requested = params.key?(:scope) ? params[:scope].to_s.split : granted

      if requested.present? && requested.all? { |scope| granted.include?(scope) }
        @refresh_permission = requested.include?("write") ? "write" : "read"
      else
        oauth_error "invalid_scope", "Requested scope exceeds the original grant"
      end
    end

    def granted_scopes(permission)
      Oauth.canonical_scope(permission).split
    end

    # A request attempts client authentication when it uses Basic, names a
    # confidential client, or carries a client secret, and then it must
    # authenticate a confidential client whatever the grant (see
    # Oauth::ClientAuthentication). A request naming a public client attempts
    # none; if its grant belongs to a confidential client, validate_client_id
    # refuses it as issued to another client, the same answer as for a dead
    # grant. So a confidential grant is only ever redeemed by the client it
    # names, authenticated.
    def authenticate_client
      reject_ambiguous_client_credentials

      unless performed? || !attempts_client_authentication? || authenticated_client&.confidential?
        client_authentication_failed
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
