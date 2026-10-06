# Token revocation (RFC 7009). The server validates the client's credentials
# and that the token was issued to it (§2.1), so a client revokes only its own
# tokens: a confidential client authenticates, and a public client names its
# client_id. Anything else that fails to identify a client, and any token that
# is unknown or belongs to another client, gets the same 200 as a successful
# revocation (§2.2), so the endpoint is no oracle for which tokens or clients
# exist. Only failed authentication is refused: a known confidential client
# with a missing or wrong secret, or a Basic header that doesn't authenticate.
class Oauth::RevocationsController < Oauth::BaseController
  include Oauth::ClientAuthentication

  allow_unauthenticated_access
  skip_forgery_protection

  before_action :reject_ambiguous_client_credentials
  before_action :require_token

  def create
    if client = authenticated_client
      revocable_tokens(client).find_by(token: params[:token])&.destroy ||
        revocable_tokens(client).find_by(refresh_token: params[:token])&.destroy

      head :ok
    elsif client_secret_basic? || requesting_client&.confidential?
      client_authentication_failed
    else
      head :ok
    end
  end

  private
    def require_token
      unless params[:token].is_a?(String) && params[:token].present?
        oauth_error "invalid_request", "token is required"
      end
    end

    def revocable_tokens(client)
      Identity::AccessToken.oauth.where(oauth_client: client)
    end
end
