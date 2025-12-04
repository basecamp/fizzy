module NetworkGuard
  class RestrictedHostError < StandardError; end

  extend self

  RESTRICTED_IP_RANGES = [
    # IPv4 mapped to IPv6
    IPAddr.new("::ffff:0:0/96"),
    # Broadcasts
    IPAddr.new("0.0.0.0/8")
  ].freeze

  def restricted_host?(hostname, **options)
    resolve(hostname, **options).any?
  rescue RestrictedHostError
    false
  end

  def resolve(hostname, timeout: nil)
    ip_addresses = []

    Resolv::DNS.open(timeouts: timeout) do |dns|
      dns.each_address(hostname) do |ip_address|
        ip_addresses << IPAddr.new(ip_address)
      end
    end

    if ip_addresses.any? { |ip_address| restricted_ip_address?(ip_address) }
      raise RestrictedHostError
    else
      ip_addresses
    end
  end

  def restricted_ip_address?(ip_address)
    ip_address.private? ||
      ip_address.loopback? ||
      DISALLOWED_IP_RANGES.any? { |range| range.include?(ip_address) }
  end
end
