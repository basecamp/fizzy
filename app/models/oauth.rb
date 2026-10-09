module Oauth
  LOOPBACK_HOSTS = %w[ 127.0.0.1 localhost ::1 [::1] ]

  # Write permits every request, reads included, so a grant that includes
  # write is reported as "read write" wherever it is shown or echoed.
  def self.canonical_scope(scope)
    scope.to_s.split.include?("write") ? "read write" : "read"
  end

  def self.loopback_host?(host)
    LOOPBACK_HOSTS.include?(URI.decode_www_form_component(host.to_s).downcase)
  rescue ArgumentError
    # A percent-encoding that decodes to invalid UTF-8 is not a usable host.
    # Surface it as an invalid URI so every caller — all of which already
    # rescue URI::InvalidURIError — rejects it instead of raising a 500.
    raise URI::InvalidURIError, "invalid percent-encoding in host"
  end

  # A host made of letters, digits, hyphens and dots, or a bracketed IPv6
  # literal. Percent-encoding, which browsers decode, isn't plain.
  PLAIN_HOST = /\A(?:\[[0-9a-f:.]+\]|[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)*)\z/i

  # A self-registered redirect must name its destination plainly, so that
  # consent shows the host a browser will actually reach and loopback matching
  # compares like with like. That means no userinfo, a plain host, and a port
  # a browser accepts. Rejecting anything else at registration, rather than
  # canonicalizing it wherever it's shown or compared, keeps one rule in one place.
  def self.plain_authority?(uri)
    uri.userinfo.nil? && plain_host?(uri.host.to_s) && uri.port.to_i.between?(1, 65535)
  end

  # Browsers parse a host whose last label is a number, decimal or 0x hex, as
  # IPv4 (WHATWG URL's ends-in-a-number check), and read a leading zero as
  # octal. So such a host is plain only as a dotted quad of canonical decimal
  # octets: 0-255, with no leading zeroes.
  DECIMAL_OCTET = /(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)/
  DOTTED_QUAD = /\A#{DECIMAL_OCTET}(?:\.#{DECIMAL_OCTET}){3}\z/

  def self.plain_host?(host)
    if host.match?(/(?:\A|\.)(?:\d+|0x\h*)\z/i)
      host.match?(DOTTED_QUAD)
    else
      host.match?(PLAIN_HOST)
    end
  end

  def self.table_name_prefix
    "oauth_"
  end
end
