class Oauth::ClientsController < Oauth::BaseController
  allow_unauthenticated_access

  rate_limit to: 10, within: 1.minute, only: :create, with: :oauth_rate_limit_exceeded

  before_action :validate_redirect_uris
  before_action :validate_loopback_uris
  before_action :validate_auth_method

  def create
    client = Oauth::Client.create! \
      name: params[:client_name] || "MCP Client",
      redirect_uris: Array(params[:redirect_uris]),
      scopes: validated_scopes,
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

    def validate_loopback_uris
      unless performed? || all_loopback_uris?(params[:redirect_uris])
        oauth_error "invalid_redirect_uri", "Only loopback redirect URIs are allowed for dynamic registration"
      end
    end

    def validate_auth_method
      unless performed? || params[:token_endpoint_auth_method].blank? || params[:token_endpoint_auth_method] == "none"
        oauth_error "invalid_client_metadata", "Only 'none' token_endpoint_auth_method is supported"
      end
    end

    def all_loopback_uris?(uris)
      uris.is_a?(Array) &&
        uris.all? { |uri| uri.is_a?(String) && valid_loopback_uri?(uri) }
    end

    def valid_loopback_uri?(uri)
      parsed = URI.parse(uri)
      parsed.scheme == "http" &&
        Oauth::LOOPBACK_HOSTS.include?(parsed.host) &&
        parsed.fragment.nil?
    rescue URI::InvalidURIError
      false
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
        client_name: client.name,
        redirect_uris: client.redirect_uris,
        token_endpoint_auth_method: "none",
        grant_types: %w[ authorization_code ],
        response_types: %w[ code ],
        scope: client.scopes.join(" ")
      }
    end
end
