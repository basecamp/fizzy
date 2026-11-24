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
# don't know the app, its fetch budget counts per registrable domain, and each
# registrable domain registers at most DomainQuota::CAP clients a window.
#
# - Url:         strict identifier validation, with no normalization
# - Fetcher:     the SSRF-guarded HTTP fetch and its caching arithmetic
# - FetchLease:  the bound on fetches in flight across processes
# - Document:    JSON validation and mapping to client attributes
# - DomainQuota: the open tier's registrations per registrable domain
# - Resolver:    lookup, fetch and persist, for the authorization endpoint
module Oauth::ClientMetadata
  extend self

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

  # Where the open tier's budgets pool, wider than a host on purpose: with
  # wildcard DNS, subdomains are free to rotate through, so the fetch budget and
  # the registration quota count the registrable domain. A host with none (an IP
  # literal, a single label) counts as itself.
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
