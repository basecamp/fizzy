class Oauth::ProtectedResourceMetadataController < Oauth::BaseController
  allow_unauthenticated_access

  def show
    render json: {
      resource: root_url(script_name: nil),
      authorization_servers: [ root_url(script_name: nil) ],
      bearer_methods_supported: %w[ header ],
      scopes_supported: %w[ read write ]
    }
  end
end
