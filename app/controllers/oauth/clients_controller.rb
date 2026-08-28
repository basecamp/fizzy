class Oauth::ClientsController < Oauth::BaseController
  allow_unauthenticated_access
  skip_forgery_protection

  after_action :prevent_caching

  rate_limit to: 10, within: 1.minute, only: :create, with: :oauth_rate_limit_exceeded

  before_action :validate_redirect_uris
  before_action :validate_redirect_uri_origins
  before_action :validate_auth_method

  def create
    client = Oauth::Client.create! \
      name: params[:client_name] || "MCP Client",
      redirect_uris: Array(params[:redirect_uris]),
      scopes: validated_scopes,
      token_endpoint_auth_method: registered_auth_method,
      dynamically_registered: true

    render json: dynamic_client_registration_response(client), status: :created
  rescue ActiveRecord::RecordInvalid => e
    oauth_error "invalid_client_metadata", e.message
  end

  private
    def validate_redirect_uris
      unless performed? || params[:redirect_uris].present?
        oauth_error "invalid_client_metadata", "redirect_uris is required"
      end
    end

    def validate_redirect_uri_origins
      unless performed? || all_registrable_uris?(params[:redirect_uris])
        oauth_error "invalid_redirect_uri", "Only https or local loopback redirect URIs are allowed for dynamic registration"
      end
    end

    def validate_auth_method
      unless performed? || registered_auth_method.in?(%w[ none client_secret_post ])
        oauth_error "invalid_client_metadata", "Only 'none' and 'client_secret_post' token_endpoint_auth_methods are supported"
      end
    end

    def registered_auth_method
      params[:token_endpoint_auth_method].presence || "none"
    end

    def all_registrable_uris?(uris)
      uris.is_a?(Array) &&
        uris.all? { |uri| uri.is_a?(String) && registrable_uri?(uri) }
    end

    def registrable_uri?(uri)
      parsed = URI.parse(uri)
      parsed.fragment.nil? && (loopback_uri?(parsed) || https_uri?(parsed))
    rescue URI::InvalidURIError
      false
    end

    def loopback_uri?(parsed)
      parsed.scheme == "http" && Oauth.loopback_host?(parsed.host)
    end

    def https_uri?(parsed)
      parsed.scheme == "https" && parsed.host.present? && !Oauth.loopback_host?(parsed.host)
    end

    def validated_scopes
      requested = case params[:scope]
      when String then params[:scope].split
      when Array then params[:scope].select { |s| s.is_a?(String) }
      else []
      end
      requested.select { |s| s.presence_in %w[ read write ] }.presence || %w[ read ]
    end

    def dynamic_client_registration_response(client)
      {
        client_id: client.client_id,
        client_secret: client.client_secret,
        client_secret_expires_at: (0 if client.client_secret),
        client_name: client.name,
        redirect_uris: client.redirect_uris,
        token_endpoint_auth_method: client.token_endpoint_auth_method,
        grant_types: %w[ authorization_code refresh_token ],
        response_types: %w[ code ],
        scope: client.scopes.join(" ")
      }.compact
    end
end
