class Oauth::ClientsController < Oauth::BaseController
  allow_unauthenticated_access
  skip_forgery_protection

  # Availability first: rate_limit is a before_action too, so a dark endpoint
  # that counted requests first would answer 429 to the eleventh, not 404.
  before_action :require_issuance_enabled
  rate_limit to: 10, within: 1.minute, only: :create, with: :oauth_rate_limit_exceeded
  before_action :require_single_valued_parameters
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

    # Registration metadata may give scope as a list (validated_scopes), and
    # its other lists, redirect_uris and grant_types, aren't single-valued names.
    def list_valued_parameter_names
      %w[ scope ]
    end

    def refuse_malformed_parameters(names)
      oauth_error "invalid_client_metadata", malformed_parameters_description(names)
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
        oauth_error "invalid_redirect_uri", registrable_uris_description
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
      Oauth.dcr_redirect_shape?(parsed) && Oauth.dcr_vetted_https_redirect?(parsed)
    rescue URI::InvalidURIError
      false
    end

    def registrable_uris_description
      schemes = Oauth::DCR_CUSTOM_SCHEMES.map { |scheme| "#{scheme}://" }.join(" or ")
      hosts = Oauth.dcr_allowed_https_hosts

      "Dynamic registration accepts local loopback redirect URIs (http://127.0.0.1, http://[::1] or http://localhost), " \
        "#{schemes} app redirects, " \
        "#{hosts.any? ? "and https redirects on #{hosts.join(", ")}" : "and no https redirects on this server"}"
    end

    def registered_client_name
      (params[:client_name] if params[:client_name].is_a?(String)).presence || "MCP Client"
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
