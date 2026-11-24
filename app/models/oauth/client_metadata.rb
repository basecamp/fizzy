# Client ID Metadata Documents (CIMD, draft-ietf-oauth-client-id-metadata-document):
# a client identified by the https URL of a metadata document it hosts. Fizzy
# fetches the URL, validates the JSON, and provisions an Oauth::Client row from
# it, with no registration request and one stable identity per app. Claude,
# ChatGPT and Perplexity connectors identify this way.
#
# Ported from bc3's Oauth::ClientMetadata, with both its tiers. A document is
# fetched only from a host named exactly in config.x.oauth.cimd_allowed_hosts
# (OAUTH_CIMD_ALLOWED_HOSTS, e.g. "mcp.claude.ai claude.ai claude.com
# chatgpt.com www.perplexity.ai"). Every other URL-shaped client_id is an unknown client, and is
# never fetched, unless open registration is on
# (Oauth::Availability.cimd_open_registration_enabled?). Then any other https
# host is the open tier: its consent screen and Connected Apps entry say we
# don't know the app.
#
# What contains the open tier, since anyone can publish a document:
#
# - Every new client costs a fetch, and fetches are bounded: per registrable
#   domain across the whole site, and overall by the fetcher's bulkhead and
#   the FetchLease across processes (Resolver).
# - A client nobody holds a grant to is swept a day after it was last used
#   (Oauth::Client.cleanup), and comes back from its document when it's used
#   again. So rows only last while someone has connected the app.
# - One person can hold grants to at most GRANT_CAP open-tier apps, which
#   bounds the rows that do last to the people connecting them.
# - An operator can block a domain outright (blocked?), for an incident.
#
# bc3 also caps the clients each registrable domain registers, in a table of
# its own. That cap doesn't hold back someone with many domains, which free
# hosting subdomains make cheap, and it refuses a busy multi-tenant host's
# users with nothing to say why; the sweep and the per-person cap bound the
# rows without it.
#
# - Url:        strict identifier validation, with no normalization
# - Fetcher:    the SSRF-guarded HTTP fetch and its caching arithmetic
# - FetchLease: the bound on fetches in flight across processes
# - Document:   JSON validation and mapping to client attributes
# - Resolver:   lookup, fetch and persist, for the authorization endpoint
module Oauth::ClientMetadata
  extend self

  # The open-tier apps one person may hold grants to at once. Each is a row
  # nothing sweeps while the grant lasts, so this bounds what one account
  # can keep. Disconnecting one frees its place.
  GRANT_CAP = 20

  # Exact host match: the allowlist names hosts, not domains, so a subdomain of
  # an allowed host isn't recognized, and nor is a lookalike.
  def tier(client_id)
    if recognized?(client_id)
      :recognized
    else
      :open
    end
  end

  def recognized?(client_id)
    host = Url.host(client_id)
    host.present? && allowed_hosts.include?(host)
  end

  def allowed_hosts
    Array(Rails.application.config.x.oauth.cimd_allowed_hosts)
  end

  # A host an operator has blocked (config.x.oauth.cimd_blocked_domains), in
  # either tier: the entry itself, or any host under it at a label boundary.
  # So a registrable domain blocks every host under it, and a narrower entry
  # only what's under that.
  def blocked?(client_id)
    if host = Url.host(client_id)&.downcase
      blocked_domains.any? { |domain| host == domain || host.end_with?(".#{domain}") }
    else
      false
    end
  end

  def blocked_domains
    Array(Rails.application.config.x.oauth.cimd_blocked_domains).map(&:downcase)
  end

  # Whether the identity already holds grants to as many open-tier apps as
  # GRANT_CAP allows, besides the client_id it's asking to authorize, so
  # authorizing an app again is never refused. Grants count while they're
  # live, as Connected Apps lists them: a revoked or lapsed one is gone.
  def grant_cap_reached?(identity, client_id)
    connected = identity.access_tokens.grants.unlapsed.joins(:oauth_client).merge(Oauth::Client.metadata_documents)
      .distinct.pluck("oauth_clients.client_id")

    connected.count { |connected_id| connected_id != client_id && tier(connected_id) == :open } >= GRANT_CAP
  end

  # Where the open tier's fetch budget pools, wider than a host on purpose:
  # with wildcard DNS, subdomains are free to rotate through, so the budget
  # counts the registrable domain. A host with none (an IP literal, a single
  # label) counts as itself.
  #
  # The key is canonical where the identifier isn't: DNS names are
  # case-insensitive and IPv6 addresses have several spellings, so a case
  # variant, or [::1] beside [0:0:0:0:0:0:0:1], shares one budget rather than
  # minting another.
  def registrable_domain(host)
    if address = ip_literal(host)
      # PublicSuffix would read an IP literal as a hostname whose "TLD" is its
      # last octet.
      address.to_s
    else
      (PublicSuffix.domain(host) || host.to_s).downcase
    end
  rescue PublicSuffix::Error
    host.to_s.downcase
  end

  private
    def ip_literal(host)
      IPAddr.new(host.to_s.delete_prefix("[").delete_suffix("]"))
    rescue IPAddr::InvalidAddressError
      nil
    end
end
