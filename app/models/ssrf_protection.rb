module SsrfProtection
  extend self

  DNS_RESOLUTION_TIMEOUT = 2

  DISALLOWED_IP_RANGES = [
    IPAddr.new("0.0.0.0/8") # Broadcasts
  ].freeze

  def resolve_public_ip(hostname)
    ip_addresses = resolve_dns(hostname)
    
    # In development, allow private IPs for local testing (e.g., host.docker.internal)
    if Rails.env.development?
      ip_addresses.first&.to_s
    else
      public_ips = ip_addresses.reject { |ip| private_address?(ip) }
      public_ips.first&.to_s
    end
  end

  def private_address?(ip)
    ip = IPAddr.new(ip.to_s) unless ip.is_a?(IPAddr)
    ip.private? || ip.loopback? || ip.link_local? || ip.ipv4_mapped? || in_disallowed_range?(ip)
  end

  private
    def resolve_dns(hostname)
      ip_addresses = []

      # Use Socket.getaddrinfo which respects /etc/hosts (for host.docker.internal, localhost, etc.)
      begin
        Socket.getaddrinfo(hostname, nil, Socket::AF_UNSPEC, Socket::SOCK_STREAM).each do |addr_info|
          ip_addresses << IPAddr.new(addr_info[3]) # addr_info[3] is the IP address
        end
      rescue SocketError
        # Hostname not found, try DNS resolution as fallback
        begin
          Resolv::DNS.open(timeouts: DNS_RESOLUTION_TIMEOUT) do |dns|
            dns.each_address(hostname) do |ip_address|
              ip_addresses << IPAddr.new(ip_address.to_s)
            end
          end
        rescue Resolv::ResolvError, Resolv::ResolvTimeout
          # DNS resolution also failed
        end
      end

      ip_addresses.uniq
    end

    def in_disallowed_range?(ip)
      DISALLOWED_IP_RANGES.any? { |range| range.include?(ip) }
    end
end
