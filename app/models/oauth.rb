module Oauth
  LOOPBACK_HOSTS = %w[ 127.0.0.1 localhost ::1 [::1] ]

  # Write permits every request, reads included, so a grant that includes
  # write is reported as "read write" wherever it is shown or echoed.
  def self.canonical_scope(scope)
    scope.to_s.split.include?("write") ? "read write" : "read"
  end

  # offline_access asks for a refresh token (OpenID Connect Core §11). It
  # names no access, and every grant Fizzy issues carries a refresh token
  # anyway, so a request that names it is weighed without it, as bc3 accepts
  # and drops it: Claude, Cursor and Muse send it beside the scopes they want.
  REFRESH_ONLY_SCOPES = %w[ offline_access ]

  # The scopes a request names, less the refresh-only ones. A request naming
  # nothing else names no scope at all.
  def self.requested_scopes(scope)
    scope.to_s.split - REFRESH_ONLY_SCOPES
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
  # - an https redirect on any plain host but this install's own
  #   (dcr_own_redirect_host?).
  #
  # https is accepted on any other host because hosted MCP clients (VS Code's
  # vscode.dev, per-tenant hosts like Glean's, Cursor's cloud agents) call
  # back over https, and a client registers its redirects as a set that's
  # refused whole, so a host allowlist refused every client nobody had listed.
  # The backstop is consent: a self-registered client is never trusted, the
  # consent screen names it by the host its code goes to, an error is never
  # bounced to that host unprompted (Oauth::Client#vetted_redirect?), and
  # registration is rate limited.
  #
  # Only cursor and claude are accepted as schemes: they are the desktop MCP
  # clients confirmed to send one. Dotted reverse-DNS schemes get no pass on
  # shape, since some dotted schemes route to a remote handler (z39.50r,
  # iris.beep). Add a scheme only when a real client is confirmed to need it.
  DCR_CUSTOM_SCHEMES = %w[ cursor claude ]

  # Domains 37signals runs, refused with every host under them. Consent names
  # a self-registered client by the host its code goes to, so one returning to
  # any of these would read as ours.
  DCR_OWN_REDIRECT_DOMAINS = %w[ fizzy.do fizzy-staging.com fizzy-beta.com 37signals.com basecamp.com basecampapi.com hey.com ]

  # This install's own host, from its URL options (BASE_URL), and the domains
  # above. Case-insensitive; a plain host has no trailing dot to ignore.
  def self.dcr_own_redirect_host?(host)
    host = host.to_s.downcase

    host.in?(dcr_install_hosts) || DCR_OWN_REDIRECT_DOMAINS.any? { |domain| host == domain || host.end_with?(".#{domain}") }
  end

  def self.dcr_install_hosts
    [ Rails.application.routes.default_url_options[:host], Rails.application.config.action_mailer.default_url_options&.dig(:host) ] \
      .compact_blank.map(&:downcase)
  end

  # Whether a redirect has the shape a self-registered client may hold: no
  # fragment, and http loopback, https on a plain host, or an allowlisted
  # private-use scheme with a target. Whether its https host is one of ours
  # is judged only when a registration adds it (Oauth::Client), so a client
  # registered before that rule stays valid.
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

  # A remote https redirect a registration may add: on any host but ours.
  def self.dcr_admissible_https_redirect?(uri)
    uri.scheme&.downcase != "https" || !dcr_own_redirect_host?(uri.host)
  end

  def self.table_name_prefix
    "oauth_"
  end
end
