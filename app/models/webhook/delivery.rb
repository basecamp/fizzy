class Webhook::Delivery < ApplicationRecord
  USER_AGENT = "fizzy/1.0.0 Webhook"
  ENDPOINT_TIMEOUT = 7.seconds
  DNS_RESOLUTION_TIMEOUT = 2
  PRIVATE_IP_RANGES = [
    # IPv4 mapped to IPv6
    IPAddr.new("::ffff:0:0/96"),
    # Broadcasts
    IPAddr.new("0.0.0.0/8")
  ].freeze

  belongs_to :webhook
  belongs_to :event

  encrypts :request, :response

  store :request, coder: JSON
  store :response, coder: JSON

  enum :state, %w[ pending in_progress completed errored ].index_by(&:itself), default: :pending

  scope :ordered, -> { order created_at: :desc, id: :desc }

  after_create_commit :deliver_later

  def deliver_later
    Webhook::DeliveryJob.perform_later(self)
  end

  def deliver
    in_progress!

    self.request[:headers] = headers
    self.response = perform_request
    self.state = :completed
    save!

    webhook.delinquency_tracker.record_delivery_of(self)
  rescue
    errored!
    raise
  end

  def succeeded?
    completed? && response[:error].blank? && response[:code].between?(200, 299)
  end

  private
    def perform_request
      if private_uri?
        { error: :private_uri }
      else
        response = http.request(
          Net::HTTP::Post.new(uri, headers).tap { |request| request.body = payload }
        )

      { code: response.code.to_i, headers: response.to_hash }
      end
    rescue Resolv::ResolvTimeout, Resolv::ResolvError, SocketError
      { error: :dns_lookup_failed }
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ETIMEDOUT
      { error: :connection_timeout }
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ECONNRESET
      { error: :destination_unreachable }
    rescue OpenSSL::SSL::SSLError
      { error: :failed_tls }
    end

    def private_uri?
      ip_addresses = []

      Resolv::DNS.open(timeouts: DNS_RESOLUTION_TIMEOUT) do |dns|
      dns.each_address(uri.host) do |ip_address|
          ip_addresses << IPAddr.new(ip_address)
        end
      end

      ip_addresses.any? do |ip|
        ip.private? || ip.loopback? || PRIVATE_IP_RANGES.any? { |range| range.include?(ip) }
      end
    end

    def uri
      @uri ||= URI(webhook.url)
    end

    def http
      Net::HTTP.new(uri.host, uri.port).tap do |http|
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = ENDPOINT_TIMEOUT
        http.read_timeout = ENDPOINT_TIMEOUT
      end
    end

    def headers
      {
        "User-Agent" => USER_AGENT,
        "Content-Type" => "application/json",
        "X-Webhook-Signature" => signature,
        "X-Webhook-Timestamp" => Time.current.utc.iso8601
      }
    end

    def signature
      OpenSSL::HMAC.hexdigest("SHA256", webhook.signing_secret, payload)
    end

    def payload
      { test: :test }.to_json
    end
end
