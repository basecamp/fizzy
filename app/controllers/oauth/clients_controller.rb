class Oauth::ClientsController < Oauth::BaseController
  allow_unauthenticated_access
  skip_forgery_protection

  rate_limit to: 10, within: 1.minute, only: :create, with: :oauth_rate_limit_exceeded

  before_action :require_issuance_enabled
  before_action :validate_redirect_uris
  before_action :validate_redirect_uri_origins
  before_action :validate_auth_method

  def create
    client = Oauth::Client.create! \
      name: registered_client_name,
      redirect_uris: Array(params[:redirect_uris]),
      scopes: validated_scopes,
      token_endpoint_auth_method: registered_auth_method,
      dynamically_registered: true

    render json: dynamic_client_registration_response(client), status: :created
  rescue ActiveRecord::RecordInvalid => e
    oauth_error "invalid_client_metadata", e.message
  end

  private
    # A registration creates a client rather than acting for one, so a
    # client_id it carries earns no pilot exemption: registration stays dark.
    def piloting_client_id
      nil
    end

    # Bounded before any URI is parsed, so an oversized list costs nothing more
    # than reading the request.
    def validate_redirect_uris
      unless performed?
        if params[:redirect_uris].blank?
          oauth_error "invalid_client_metadata", "redirect_uris is required"
        elsif !bounded_redirect_uris?(params[:redirect_uris])
          oauth_error "invalid_client_metadata", "redirect_uris may list at most #{Oauth::Client::MAXIMUM_REDIRECT_URIS} URIs of at most #{Oauth::Client::MAXIMUM_REDIRECT_URI_LENGTH} characters each"
        end
      end
    end

    # Anything but a list of strings is refused as unregistrable afterwards.
    def bounded_redirect_uris?(uris)
      !uris.is_a?(Array) || (uris.size <= Oauth::Client::MAXIMUM_REDIRECT_URIS &&
        uris.all? { |uri| !uri.is_a?(String) || uri.length <= Oauth::Client::MAXIMUM_REDIRECT_URI_LENGTH })
    end

    def validate_redirect_uri_origins
      unless performed? || all_registrable_uris?(params[:redirect_uris])
        oauth_error "invalid_redirect_uri", "Only https or local loopback redirect URIs are allowed for dynamic registration"
      end
    end

    def validate_auth_method
      unless performed? || registered_auth_method.in?(Oauth::Client::AUTH_METHODS)
        oauth_error "invalid_client_metadata", "token_endpoint_auth_method must be one of #{Oauth::Client::AUTH_METHODS.join(", ")}"
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

    def registered_client_name
      (params[:client_name] if params[:client_name].is_a?(String)).presence || "MCP Client"
    end

    def loopback_uri?(parsed)
      parsed.scheme == "http" && Oauth.plain_authority?(parsed) && Oauth.loopback_host?(parsed.host)
    end

    def https_uri?(parsed)
      parsed.scheme == "https" && Oauth.plain_authority?(parsed) && !Oauth.loopback_host?(parsed.host)
    end

    def validated_scopes
      requested = case params[:scope]
      when String then params[:scope].split
      when Array then params[:scope].select { |s| s.is_a?(String) }
      else []
      end
      Oauth.canonical_scope(requested.join(" ")).split
    end

    def dynamic_client_registration_response(client)
      {
        client_id: client.client_id,
        client_secret: client.raw_client_secret,
        client_secret_expires_at: (0 if client.raw_client_secret),
        client_name: client.name,
        redirect_uris: client.redirect_uris,
        token_endpoint_auth_method: client.token_endpoint_auth_method,
        grant_types: %w[ authorization_code refresh_token ],
        response_types: %w[ code ],
        scope: client.scopes.join(" ")
      }.compact
    end
end
