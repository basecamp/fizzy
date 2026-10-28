module Oauth
  LOOPBACK_HOSTS = %w[ 127.0.0.1 localhost ::1 [::1] ]

  # Write permits every request, reads included, so a grant that includes
  # write is reported as "read write" wherever it is shown or echoed.
  def self.canonical_scope(scope)
    scope.to_s.split.include?("write") ? "read write" : "read"
  end

  # The protected resources, other than Fizzy's own API, that an OAuth grant
  # may be issued for (RFC 8707): the hosted MCP server's resource URL, by
  # exact string, from FIZZY_OAUTH_MCP_RESOURCES. None unless configured.
  def self.mcp_resources
    Array(Rails.application.config.x.oauth.mcp_resources)
  end

  def self.mcp_resource?(resource)
    resource.is_a?(String) && resource.present? && mcp_resources.include?(resource)
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

  # Each OAuth sweep runs as its own recurring job, and a failure still fails
  # that job. It's also announced, as cleanup_failure.oauth, so a sweep that
  # keeps failing can be counted and alerted on (SaaS counts it in Yabeda)
  # rather than found later as the rows it left behind.
  def self.cleanup_step(step)
    yield
  rescue => error
    ActiveSupport::Notifications.instrument "cleanup_failure.oauth", step: step, error_class: error.class.name
    raise
  end

  # Dynamic client registration is open and unauthenticated, so a remote
  # callback is the sink an attacker who registers a client would point codes
  # at. Self-registered clients may therefore name only:
  #
  # - an http loopback redirect (RFC 8252 §7.3), served on the user's device;
  # - a private-use scheme from DCR_CUSTOM_SCHEMES (RFC 8252 §7.1), dispatched
  #   by the operating system to an app on the user's device;
  # - an https redirect on a vetted vendor host (dcr_allowed_https_hosts).
  #
  # Only cursor and claude are accepted as schemes: they are the desktop MCP
  # clients confirmed to send one. Dotted reverse-DNS schemes get no pass on
  # shape, since some dotted schemes route to a remote handler (z39.50r,
  # iris.beep). Add a scheme or a host only when a real client is confirmed
  # to need it. The consent screen, which always shows where the code goes,
  # stays the backstop.
  DCR_CUSTOM_SCHEMES = %w[ cursor claude ]

  # The vetted https callback hosts, from OAUTH_DCR_ALLOWED_HTTPS_HOSTS in
  # production. None by default, so an install that never names one accepts
  # only on-device redirects.
  def self.dcr_allowed_https_hosts
    Array(Rails.configuration.x.oauth.dcr_allowed_https_hosts).map(&:downcase)
  end

  def self.dcr_allowed_https_host?(host)
    dcr_allowed_https_hosts.include?(host.to_s.downcase)
  end

  # Whether a redirect has the shape a self-registered client may hold: no
  # fragment, and http loopback, https on a plain host, or an allowlisted
  # private-use scheme with a target. Whether its https host is vetted is
  # judged only when a registration adds it (Oauth::Client), so a client
  # stays valid after its host leaves the list.
  def self.dcr_redirect_shape?(uri)
    uri.fragment.nil? && \
      case uri.scheme&.downcase
      when "http" then plain_authority?(uri) && loopback_host?(uri.host)
      when "https" then plain_authority?(uri) && !loopback_host?(uri.host)
      when *DCR_CUSTOM_SCHEMES then private_use_redirect?(uri)
      else false
      end
  end

  # Hierarchical (cursor://host/path, never the opaque cursor:path, which
  # can't carry the callback's query), with no userinfo, and naming a plain
  # host, which consent shows as where the code goes.
  def self.private_use_redirect?(uri)
    uri.opaque.nil? && uri.userinfo.nil? && plain_host?(uri.host.to_s)
  end

  # A remote https redirect a registration may add: an allowlisted host.
  def self.dcr_vetted_https_redirect?(uri)
    uri.scheme&.downcase != "https" || dcr_allowed_https_host?(uri.host)
  end

  def self.table_name_prefix
    "oauth_"
  end
end
