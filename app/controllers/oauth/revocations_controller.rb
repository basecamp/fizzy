# Token revocation (RFC 7009). The server validates the client's credentials
# and that the token was issued to it (§2.1), so a client revokes only its own
# tokens: a confidential client authenticates, and a public client names its
# client_id. Anything else that fails to identify a client, and any token that
# is unknown or belongs to another client, gets the same 200 as a successful
# revocation (§2.2), so the endpoint is no oracle for which tokens or clients
# exist. Only failed authentication is refused: a known confidential client
# with a missing or wrong secret, a Basic header that doesn't authenticate,
# or a client secret that authenticates no client.
#
# A personal access token was issued to no client, so possession of it is the
# credential: whoever presents one revokes it, client or not. Client
# credentials presented beside it must still authenticate, by the same rules.
class Oauth::RevocationsController < Oauth::BaseController
  include Oauth::ClientAuthentication

  allow_unauthenticated_access
  skip_forgery_protection

  # Client authentication happens here too, so secrets can be guessed here:
  # throttled like the token endpoint (RFC 6749 §2.3.1, RFC 7009 §5).
  rate_limit to: 20, within: 1.minute, only: :create, with: :oauth_rate_limit_exceeded

  before_action :reject_ambiguous_client_credentials
  before_action :require_token

  def create
    if attempts_client_authentication? && !authenticated_client
      client_authentication_failed
    else
      if grant = revocable_token
        grant.revoke reason: "revocation_endpoint", actor: "client", presented: presented_kind(grant)
      end

      head :ok
    end
  end

  private
    def require_token
      unless params[:token].is_a?(String) && params[:token].present?
        oauth_error "invalid_request", "token is required"
      end
    end

    def revocable_token
      Identity::AccessToken.personal.find_by_raw_token(params[:token]) || client_token
    end

    # Which of the grant's tokens the client presented, for metrics: its access
    # token, or a refresh token, current or retired.
    def presented_kind(grant)
      grant.token_digest.in?(TokenDigester.digests(params[:token])) ? "access" : "refresh"
    end

    # Either token of a grant revokes the whole grant, and so does a refresh
    # token it has rotated away from.
    def client_token
      if client = authenticated_client
        tokens = Identity::AccessToken.oauth.where(oauth_client: client)

        tokens.find_by_raw_token(params[:token]) || tokens.find_by_refresh_token(params[:token]) ||
          tokens.find_by(id: Oauth::RetiredRefreshToken.find_by_raw_token(params[:token])&.access_token_id)
      end
    end
end
