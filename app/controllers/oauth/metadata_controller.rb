class Oauth::MetadataController < Oauth::BaseController
  allow_unauthenticated_access

  before_action :require_acceptance_enabled

  def show
    render json: {
      issuer: oauth_issuer,
      authorization_endpoint: new_oauth_authorization_url,
      token_endpoint: oauth_token_url,
      registration_endpoint: oauth_clients_url,
      revocation_endpoint: oauth_revocation_url,
      revocation_endpoint_auth_methods_supported: Oauth::Client::AUTH_METHODS,
      response_types_supported: %w[ code ],
      response_modes_supported: %w[ query ],
      grant_types_supported: grant_types_supported,
      token_endpoint_auth_methods_supported: Oauth::Client::AUTH_METHODS,
      code_challenge_methods_supported: %w[ S256 ],
      scopes_supported: %w[ read write ],
      authorization_response_iss_parameter_supported: true
    }
  end

  private
    # The delegation exchange is advertised only where it's configured, as
    # the hosted MCP server checks for it before it starts exchanging.
    def grant_types_supported
      %w[ authorization_code refresh_token ] + (Oauth::TokenDelegation.enabled? ? [ Oauth::TokenDelegation::GRANT_TYPE ] : [])
    end
end
