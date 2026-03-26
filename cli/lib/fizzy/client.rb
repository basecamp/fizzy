require "json"
require "net/http"
require "uri"
require_relative "error"

module Fizzy
  class ApiError < Error
    attr_reader :status, :body

    def initialize(status, body)
      @status = status
      @body = body
      super("HTTP #{status}: #{body_summary}")
    end

    def body_summary
      case body
      when Hash
        body["message"] || body["error"] || body.inspect
      when String
        body
      else
        body.to_s
      end
    end
  end

  class Client
    def initialize(base_url:, token: nil)
      @base_url = base_url.end_with?("/") ? base_url : "#{base_url}/"
      @token = token
    end

    def request(method, path_or_url, params: nil)
      uri = absolute_uri(path_or_url)
      request = request_class(method).new(uri)
      request["Accept"] = "application/json"
      request["Authorization"] = "Bearer #{@token}" if @token

      if params
        request["Content-Type"] = "application/json"
        request.body = JSON.dump(params)
      end

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      body = parse_body(response)
      raise ApiError.new(response.code.to_i, body) unless response.code.to_i.between?(200, 299)

      body
    end

    private
      def absolute_uri(path_or_url)
        return URI(path_or_url) if path_or_url.start_with?("http://", "https://")

        URI.join(@base_url, path_or_url.delete_prefix("/"))
      end

      def parse_body(response)
        return nil if response.body.nil? || response.body.empty?

        content_type = response["Content-Type"].to_s
        return JSON.parse(response.body) if content_type.include?("json")

        response.body
      rescue JSON::ParserError
        response.body
      end

      def request_class(method)
        case method.to_s.upcase
        when "GET" then Net::HTTP::Get
        when "POST" then Net::HTTP::Post
        when "PUT" then Net::HTTP::Put
        when "PATCH" then Net::HTTP::Patch
        when "DELETE" then Net::HTTP::Delete
        else raise Error, "Unsupported HTTP method #{method}"
        end
      end
  end
end
