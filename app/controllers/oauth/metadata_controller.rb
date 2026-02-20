class Oauth::MetadataController < Oauth::BaseController
  allow_unauthenticated_access

  def show
    render json: {
      issuer: root_url(script_name: nil),
      authorization_endpoint: new_oauth_authorization_url,
      token_endpoint: oauth_token_url,
      registration_endpoint: oauth_clients_url,
      revocation_endpoint: oauth_revocation_url,
      response_types_supported: %w[ code ],
      grant_types_supported: %w[ authorization_code ],
      token_endpoint_auth_methods_supported: %w[ none ],
      code_challenge_methods_supported: %w[ S256 ],
      scopes_supported: %w[ read write ]
    }
  end
end
