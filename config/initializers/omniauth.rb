Rails.application.config.middleware.use OmniAuth::Builder do
  if ENV["OIDC_ISSUER"].present?
    provider :openid_connect,
      name: :oidc,
      discovery: true,
      issuer: ENV["OIDC_ISSUER"],
      client_options: {
        identifier: ENV["OIDC_CLIENT_ID"],
        secret: ENV["OIDC_CLIENT_SECRET"],
        redirect_uri: ENV.fetch("OIDC_REDIRECT_URI") { "#{ENV.fetch('BASE_URL', 'http://localhost:3000')}/auth/oidc/callback" }
      },
      scope: ENV.fetch("OIDC_SCOPES", "openid email profile").split
  end
end

OmniAuth.config.allowed_request_methods = [ :get, :post ]
OmniAuth.config.silence_get_warning = true
OmniAuth.config.on_failure = Proc.new { |env|
  Rails.logger.error "[OIDC] OmniAuth failure: #{env['omniauth.error']&.message || 'unknown'} (#{env['omniauth.error.type']})"
  Rack::Response.new([ "302 Moved" ], 302, "Location" => "/auth/failure?message=#{env['omniauth.error.type']}").finish
}
