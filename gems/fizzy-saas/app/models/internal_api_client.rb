class InternalApiClient
  SECRET_KEY = "internal_api_client_signing_secret"
  TOKEN_KEY = "internal_api_client_token"
  USER_AGENT = "fizzy/1.0.0 InternalApiClient"
  SIGNATURE_HEADER = "X-Internal-Signature"
  DEFAULT_TIMEOUT = 5.seconds

  class Error < StandardError; end
  class TimeoutError < Error; end
  class ConnectionError < Error; end

  Response = Struct.new(:code, :body, :error) do
    def parsed_body
      @parsed_body ||= JSON.parse(body) if body.present?
    end

    def success?
      error.nil? && code.between?(200, 299)
    end
  end

 attr_reader :url, :response

  class << self
    def token
      Rails.application.key_generator.generate_key(TOKEN_KEY, 32).unpack1("H*")
    end

    def signature_for(body)
      OpenSSL::HMAC.hexdigest("SHA256", signing_secret, body)
    end

    private
      def signing_secret
        Rails.application.key_generator.generate_key(SECRET_KEY, 32).unpack1("H*")
      end
  end

  def initialize(url, timeout: DEFAULT_TIMEOUT)
    @url = url
    @timeout = timeout
  end

  def post(body = nil, params: {})
    uri = build_uri(@url, params)
    payload = prepare_payload(body)
    request = Net::HTTP::Post.new(uri, headers(payload))
    request.body = payload
    perform_request(uri, request)
  end

  private
    def build_uri(url, params)
      uri = URI(url)

      if params.any?
        existing_params = URI.decode_www_form(uri.query || "").to_h
        uri.query = URI.encode_www_form(existing_params.merge(params))
      end

      uri
    end

    def prepare_payload(body)
      case body
      when nil
        ""
      when String
        body
      else
        body.to_json
      end
    end

    def headers(payload)
      {
        "User-Agent" => USER_AGENT,
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{self.class.token}",
        SIGNATURE_HEADER => self.class.signature_for(payload)
      }
    end

    def perform_request(uri, request)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      response = http.request(request)
      Response.new(code: response.code.to_i, body: response.body)
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ETIMEDOUT
      Response.new(error: :connection_timeout)
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ECONNRESET, SocketError
      Response.new(error: :destination_unreachable)
    rescue OpenSSL::SSL::SSLError
      Response.new(error: :failed_tls)
    end
end
