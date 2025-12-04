class Link::Fetch
  class Error < StandardError; end

  class TooManyRedirectsError < Error; end

  class RedirectDeniedError < Error; end

  class BodyTooLargeError < Error; end

  class UnsuccesfulRequestError < Error
    attr_reader :response

    def initialize(response)
      @response = response
      super("HTTP response code: #{response.code}")
    end
  end

  DEFAULT_USER_AGENT = "Mozilla/5.0 (compatible; FizzyLinkUnfurler/1.0.0)".freeze
  MAX_BODY_SIZE = 2.megabytes
  MAX_REDIRECTS = 10
  DNS_RESOLUTION_TIMEOUT = 2.seconds

  attr_reader :uri, :headers, :max_body_size, :dns_resolution_timeout

  def initialize(url, headers: {}, max_body_size: MAX_BODY_SIZE, dns_resolution_timeout: DNS_RESOLUTION_TIMEOUT)
    @uri = URI.parse(url)
    @headers = default_headers.merge(headers)
    @max_body_size = max_body_size
    @dns_resolution_timeout = dns_resolution_timeout
  end

  def http_url?
    uri.is_a?(URI::HTTP)
  end

  def html_content?
    content_type&.starts_with? "text/html"
  end

  def content_type
    request uri, Net::HTTP::Head do |response|
      if response.is_a?(Net::HTTPSuccess)
        return response["Content-Type"]
      else
        raise UnsuccesfulRequestError, response
      end
    end
  end

  def content
    request uri, Net::HTTP::Get do |response|
      if response.is_a?(Net::HTTPSuccess)
        body_size = 0
        buffer = StringIO.new

        response.read_body do |chunk|
          body_size += chunk.bytesize

          if body_size <= max_body_size
            buffer << chunk
          else
            raise BodyTooLargeError
          end
        end

        return buffer.string
      else
        raise UnsuccesfulRequestError, response
      end
    end
  end

  private
    def request(uri, request_class, ip_address: nil)
      ip_address ||= resolve_ip_address(uri.host)

      MAX_REDIRECTS.times do
        Net::HTTP.start(uri.host, uri.port, ipaddr: ip_address, use_ssl: uri.scheme == "https") do |http|
          request = request_class.new(uri)

          headers.each do |header, value|
            request[header] = value
          end

          http.request(request) do |response|
            if response.is_a?(Net::HTTPRedirection)
              uri, ip_address = resolve_redirect(response["location"])
            else
              yield response
            end
          end
        end
      end

      raise TooManyRedirectsError
    end

    def default_headers
      {
        "Accept" => "text/html,application/xhtml+xml",
        "User-Agent" => DEFAULT_USER_AGENT
      }
    end

    def resolve_redirect(location)
      uri = URI.parse(location)
      raise RedirectDeniedError unless uri.is_a?(URI::HTTP)

      [ uri, resolve_ip_address(uri.host) ]
    rescue NetworkGuard::RestrictedHostError
      raise RedirectDeniedError
    end

    def resolve_ip_address(hostname)
      NetworkGuard.resolve(hostname, timeout: dns_resolution_timeout).sample
    end
end
