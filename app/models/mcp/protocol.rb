module Mcp::Protocol
  extend ActiveSupport::Concern

  JSONRPC_VERSION = "2.0"

  included do
    before_action :parse_jsonrpc_request, only: :create
    before_action :validate_protocol_version, only: :create
  end

  private
    attr_reader :jsonrpc_id, :jsonrpc_method, :jsonrpc_params, :protocol_version

    def notification?
      !params.key?(:id)
    end

    def parse_jsonrpc_request
      @jsonrpc_id = params[:id]
      @jsonrpc_method = params[:method]
      @jsonrpc_params = params[:params] || {}
    end

    def validate_protocol_version
      # Initialize doesn't require version header (it's where version is negotiated)
      return if jsonrpc_method == "initialize"

      version = request.headers["MCP-Protocol-Version"]

      # Per spec: if no header and no other way to identify, assume 2025-03-26
      @protocol_version = version.presence || "2025-03-26"

      unless Mcp::SUPPORTED_VERSIONS.include?(@protocol_version)
        jsonrpc_error :invalid_request, "Unsupported protocol version: #{@protocol_version}"
      end
    end

    def jsonrpc_response(result)
      # JSON-RPC 2.0: Notifications don't receive responses
      return head(:accepted) if notification?

      render json: {
        jsonrpc: JSONRPC_VERSION,
        id: jsonrpc_id,
        result: result
      }
    end

    def jsonrpc_error(code, message = nil, data: nil)
      # JSON-RPC 2.0: Notifications don't receive responses (even errors)
      return head(:accepted) if notification?
      error = case code
      when :parse_error      then { code: -32700, message: message || "Parse error" }
      when :invalid_request  then { code: -32600, message: message || "Invalid request" }
      when :method_not_found then { code: -32601, message: message || "Method not found" }
      when :invalid_params   then { code: -32602, message: message || "Invalid params" }
      when :internal_error   then { code: -32603, message: message || "Internal error" }
      else { code: code, message: message }
      end

      error[:data] = data if data.present?

      render json: {
        jsonrpc: JSONRPC_VERSION,
        id: jsonrpc_id,
        error: error
      }, status: error_status(code)
    end

    def error_status(code)
      case code
      when :parse_error, :invalid_request, :invalid_params then :bad_request
      when :method_not_found then :not_found
      else :internal_server_error
      end
    end
end
