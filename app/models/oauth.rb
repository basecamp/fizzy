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
    uri.userinfo.nil? && uri.host.to_s.match?(PLAIN_HOST) && uri.port.to_i.between?(1, 65535)
  end

  def self.table_name_prefix
    "oauth_"
  end
end
