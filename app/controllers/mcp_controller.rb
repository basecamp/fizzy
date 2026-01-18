class McpController < ApplicationController
  include Mcp::Protocol

  disallow_account_scope
  allow_unauthenticated_access
  before_action :require_bearer_token, only: :create

  def discovery
    render json: {
      name: "Fizzy",
      description: "Kanban workflow management",
      mcp_version: Mcp::PROTOCOL_VERSION,
      capabilities: { tools: {}, resources: {} },
      oauth: { server: oauth_authorization_server_url }
    }
  end

  def create
    case jsonrpc_method
    when "initialize"       then handle_initialize
    when "tools/list"       then handle_tools_list
    when "tools/call"       then handle_tools_call
    when "resources/list"   then handle_resources_list
    when "resources/read"   then handle_resources_read
    else
      jsonrpc_error :method_not_found
    end
  rescue ActiveRecord::RecordNotFound => e
    jsonrpc_error :invalid_params, "Record not found: #{e.message}"
  rescue ActiveRecord::RecordInvalid => e
    jsonrpc_error :invalid_params, e.message
  rescue ArgumentError => e
    jsonrpc_error :invalid_params, e.message
  end

  private
    def handle_initialize
      client_version = jsonrpc_params[:protocolVersion]

      negotiated_version = if Mcp::SUPPORTED_VERSIONS.include?(client_version)
        client_version
      else
        Mcp::PROTOCOL_VERSION
      end

      jsonrpc_response({
        protocolVersion: negotiated_version,
        capabilities: { tools: {}, resources: {} },
        serverInfo: { name: "Fizzy", title: "Fizzy Kanban", version: "1.0.0" }
      })
    end

    def handle_tools_list
      jsonrpc_response Mcp::Tools.list
    end

    def handle_tools_call
      name = jsonrpc_params[:name]
      arguments = jsonrpc_params[:arguments]&.permit!&.to_h || {}

      result = Mcp::Tools.call(name, arguments, identity: Current.identity)
      jsonrpc_response result
    end

    def handle_resources_list
      jsonrpc_response Mcp::Resources.list
    end

    def handle_resources_read
      uri = jsonrpc_params[:uri]
      result = Mcp::Resources.read(uri, identity: Current.identity)
      jsonrpc_response result
    end

    def require_bearer_token
      if token = request.authorization.to_s[/\ABearer (.+)\z/i, 1]
        if access_token = Identity::AccessToken.find_by(token: token)
          if access_token.allows_operation?(mcp_operation)
            Current.identity = access_token.identity
            return
          else
            response.headers["WWW-Authenticate"] = %(Bearer error="insufficient_scope")
            head :forbidden and return
          end
        end
      end

      response.headers["WWW-Authenticate"] = %(Bearer resource_metadata="#{oauth_protected_resource_url}")
      head :unauthorized
    end

    def mcp_operation
      case jsonrpc_method
      when "tools/call" then :write
      else :read
      end
    end

    def oauth_protected_resource_url
      Rails.application.routes.url_helpers.url_for \
        controller: "oauth/protected_resource_metadata",
        action: "show",
        only_path: false,
        host: request.host,
        port: request.port,
        protocol: request.protocol
    end

    def oauth_authorization_server_url
      Rails.application.routes.url_helpers.url_for \
        controller: "oauth/metadata",
        action: "show",
        only_path: false,
        host: request.host,
        port: request.port,
        protocol: request.protocol
    end
end
