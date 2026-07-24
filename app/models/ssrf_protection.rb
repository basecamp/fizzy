module SsrfProtection
  extend self

  DNS_RESOLUTION_TIMEOUT = 2

  DNS_NAMESERVERS = %w[
    1.1.1.1
    8.8.8.8
  ]

  # IPv4 ranges that must never be a fetch target (RFC 5735/6890 special-use,
  # plus CGNAT and benchmarking). RFC1918/loopback/link-local are also covered
  # by the IPAddr predicates in #blocked_address?.
  DISALLOWED_IP_RANGES = [
    IPAddr.new("0.0.0.0/8"),       # "This" network (RFC1700)
    IPAddr.new("10.0.0.0/8"),      # Private (RFC1918)
    IPAddr.new("100.64.0.0/10"),   # Carrier-grade NAT (RFC6598)
    IPAddr.new("127.0.0.0/8"),     # Loopback
    IPAddr.new("169.254.0.0/16"),  # Link-local (incl. AWS metadata)
    IPAddr.new("172.16.0.0/12"),   # Private (RFC1918)
    IPAddr.new("192.0.0.0/24"),    # IETF protocol assignments (RFC6890)
    IPAddr.new("192.0.2.0/24"),    # TEST-NET-1 (RFC5737)
    IPAddr.new("192.88.99.0/24"),  # 6to4 relay anycast (RFC7526)
    IPAddr.new("192.168.0.0/16"),  # Private (RFC1918)
    IPAddr.new("198.18.0.0/15"),   # Benchmark testing (RFC2544)
    IPAddr.new("198.51.100.0/24"), # TEST-NET-2 (RFC5737)
    IPAddr.new("203.0.113.0/24"),  # TEST-NET-3 (RFC5737)
    IPAddr.new("224.0.0.0/4"),     # Multicast (RFC5771)
    IPAddr.new("240.0.0.0/4")      # Reserved / future use (RFC1112)
  ].freeze

  # IPv6 special-use ranges not caught by the predicates. 6to4 (2002::/16) and
  # Teredo (2001::/32) are deprecated transition mechanisms with no legitimate
  # fetch target, so they are blocked outright. ULA (fc00::/7, incl. AWS
  # IMDSv6 fd00:ec2::254), link-local, and loopback are covered by the predicates.
  DISALLOWED_IPV6_RANGES = [
    IPAddr.new("::/128"),        # Unspecified
    IPAddr.new("100::/64"),      # Discard-only (RFC6666)
    IPAddr.new("2001::/32"),     # Teredo (RFC4380)
    IPAddr.new("2001:2::/48"),   # Benchmark testing (RFC5180)
    IPAddr.new("2001:db8::/32"), # Documentation (RFC3849)
    IPAddr.new("2002::/16"),     # 6to4 (RFC3056)
    IPAddr.new("fec0::/10"),     # Deprecated site-local (RFC3879)
    IPAddr.new("ff00::/8")       # Multicast (RFC4291)
  ].freeze

  # NAT64 prefixes: the well-known prefix (RFC 6052/6146) and the local-use
  # prefix (RFC 8215). An address here embeds an IPv4 target in its low 32
  # bits; extract it and re-check against the IPv4 rules so NAT64 to a public
  # address still resolves while NAT64 to an internal address is blocked.
  NAT64_PREFIXES = [
    IPAddr.new("64:ff9b::/96"),
    IPAddr.new("64:ff9b:1::/48")
  ].freeze

  def resolve_public_ip(hostname)
    ip_addresses = resolve_dns(hostname)
    public_ips = ip_addresses.reject { |ip| blocked_address?(ip) }
    public_ips.sort_by { |ipaddr| ipaddr.ipv4? ? 0 : 1 }.first&.to_s
  end

  def blocked_address?(ip)
    ipaddr = ip.is_a?(IPAddr) ? ip : IPAddr.new(ip.to_s)

    # DNS never legitimately returns these embedded forms, so block them all
    # regardless of the address they wrap.
    if ipaddr.ipv4_mapped? || ipaddr.ipv4_compat?
      true
    elsif ipaddr.ipv4?
      disallowed_ipv4?(ipaddr)
    elsif NAT64_PREFIXES.any? { |prefix| prefix.include?(ipaddr) }
      disallowed_ipv4?(embedded_ipv4(ipaddr))
    else
      disallowed_ipv6?(ipaddr)
    end
  rescue IPAddr::InvalidAddressError
    true
  end

  private
    def resolve_dns(hostname)
      ip_addresses = []

      Resolv::DNS.open(nameserver: DNS_NAMESERVERS, timeouts: DNS_RESOLUTION_TIMEOUT) do |dns|
        dns.each_address(hostname) do |ip_address|
          ip_addresses << IPAddr.new(ip_address.to_s)
        end
      end

      ip_addresses
    end

    def disallowed_ipv4?(ipaddr)
      ipaddr.private? || ipaddr.loopback? || ipaddr.link_local? ||
        DISALLOWED_IP_RANGES.any? { |range| range.include?(ipaddr) }
    end

    def disallowed_ipv6?(ipaddr)
      ipaddr.private? || ipaddr.loopback? || ipaddr.link_local? ||
        DISALLOWED_IPV6_RANGES.any? { |range| range.include?(ipaddr) }
    end

    def embedded_ipv4(ipaddr)
      IPAddr.new([ ipaddr.to_i & 0xffffffff ].pack("N").unpack("C4").join("."))
    end
end
