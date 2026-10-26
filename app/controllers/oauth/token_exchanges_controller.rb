# The delegation exchange (RFC 8693) at the token endpoint: POST /oauth/token
# with grant_type urn:ietf:params:oauth:grant-type:token-exchange is routed
# here (see config/routes.rb). Only the hosted MCP server's own confidential
# client may use it, and Oauth::TokenDelegation decides what it gets.
#
# Rate limits: the MCP server exchanges for every person connected through
# it, from a few hosts, so once its secret verifies it's charged to a budget
# of its own, keyed on the client, as bc3's is. Anything else, a bad secret
# included, is held to the token endpoint's 20 a minute per IP.
class Oauth::TokenExchangesController < Oauth::BaseController
  include Oauth::ClientAuthentication

  CLIENT_BUDGET = 600

  allow_unauthenticated_access
  skip_forgery_protection

  # Timed with the token endpoint's other grants, under the grant it is.
  around_action :instrument_token_request

  # Availability first: rate_limit is a before_action too, so an exchange that
  # isn't on would answer 429 past the limit, rather than 404 every time. A
  # dark server answers 404 before it says which grants it supports.
  before_action :require_issuance_enabled
  before_action :require_delegation_enabled

  rate_limit to: 20, within: 1.minute, only: :create, with: :exchange_rate_limit_exceeded, unless: :authenticated_delegation_client?
  rate_limit to: CLIENT_BUDGET, within: 1.minute, only: :create, by: -> { requesting_client.client_id }, name: "client",
    with: :exchange_rate_limit_exceeded, if: :authenticated_delegation_client?

  before_action :require_single_valued_parameters
  before_action :require_form_body
  before_action :authenticate_client
  before_action :require_params

  def create
    delegation = Oauth::TokenDelegation.new \
      client: authenticated_client,
      subject_token: request.request_parameters["subject_token"],
      api_resource: method(:service_resource?),
      requested_scope: params.key?(:scope) ? params[:scope].to_s : nil,
      resource: params[:resource].presence
    delegated_token = delegation.validate!.mint!

    render json: {
      access_token: delegated_token.raw_token,
      issued_token_type: Oauth::TokenDelegation::ACCESS_TOKEN_TYPE,
      token_type: "Bearer",
      expires_in: delegated_token.expires_in,
      scope: delegation.scope
    }
  rescue Oauth::TokenDelegation::Refusal => refusal
    oauth_error refusal.error, refusal.message
  end

  private
    def instrument_token_request(&)
      ActiveSupport::Notifications.instrument "token_request.oauth", grant_type: "token_exchange", &
    end

    # A server that isn't configured for delegation answers as one that never
    # heard of the grant, which is what its metadata says.
    def require_delegation_enabled
      unless Oauth::TokenDelegation.enabled?
        oauth_error "unsupported_grant_type", "Only authorization_code and refresh_token grants are supported"
      end
    end

    # RFC 8693 §2.1 sends the request form-urlencoded, as fizzy-mcp-server
    # does, and only that body is accepted. Repeated resources are
    # single_resource?'s to refuse, in whatever body; this keeps the exchange
    # to the one encoding its one client sends.
    def require_form_body
      unless request.media_type == "application/x-www-form-urlencoded"
        oauth_error "invalid_request", "Token exchange requests must be application/x-www-form-urlencoded"
      end
    end

    # Every attempt at this grant authenticates a client: a public client
    # has no secret to prove, so naming one fails like a wrong secret.
    def authenticate_client
      reject_ambiguous_client_credentials

      unless performed? || authenticated_client&.confidential?
        client_authentication_failed
      end
    end

    # The subject token is a bearer credential, so like a client secret it's
    # read from the body alone: in the query it would be in every proxy's and
    # access log's copy of the URL.
    def require_params
      if request.query_parameters.key?("subject_token")
        oauth_error "invalid_request", "subject_token must be sent in the request body"
      elsif !string_param?(:subject_token)
        oauth_error "invalid_request", "subject_token required"
      elsif !string_param?(:subject_token_type)
        oauth_error "invalid_request", "subject_token_type required"
      elsif params[:subject_token_type] != Oauth::TokenDelegation::ACCESS_TOKEN_TYPE
        oauth_error "invalid_request", "Only access_token subject_token_type supported"
      elsif params.key?(:requested_token_type) && params[:requested_token_type] != Oauth::TokenDelegation::ACCESS_TOKEN_TYPE
        oauth_error "invalid_request", "Only access_token requested_token_type supported"
      elsif !single_resource?
        oauth_error "invalid_target", "Only one resource may be named"
      end
    end

    def string_param?(name)
      params[name].is_a?(String) && params[name].present?
    end

    # Whether the request authenticates a client the exchange is for. Read by
    # the rate limits before anything else runs, so it's worked out once.
    def authenticated_delegation_client?
      if defined?(@authenticated_delegation_client)
        @authenticated_delegation_client
      else
        @authenticated_delegation_client = Oauth::TokenDelegation.enabled? && \
          !(client_secret_basic? && request.request_parameters["client_secret"].present?) && \
          authenticated_client.then { |client| client.present? && client.confidential? && client.delegation_client? }
      end
    end

    def authenticated_client
      if defined?(@authenticated_client)
        @authenticated_client
      else
        @authenticated_client = super
      end
    end

    # bc3 answers 429 with Retry-After: 60, and the MCP server backs off by it.
    def exchange_rate_limit_exceeded
      response.headers["Retry-After"] = "60"
      oauth_rate_limit_exceeded
    end
end
