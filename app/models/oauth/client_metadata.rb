# Client ID Metadata Documents (CIMD, draft-ietf-oauth-client-id-metadata-document):
# a client identified by the https URL of a metadata document it hosts. Fizzy
# fetches the URL, validates the JSON, and provisions an Oauth::Client row from
# it, with no registration request and one stable identity per app. Claude and
# ChatGPT connectors identify this way.
#
# Ported from bc3's Oauth::ClientMetadata, recognized tier only: a document is
# fetched only from a host named exactly in config.x.oauth.cimd_allowed_hosts
# (OAUTH_CIMD_ALLOWED_HOSTS, e.g. "mcp.claude.ai claude.ai claude.com
# chatgpt.com"). Every other URL-shaped client_id is an unknown client, and is
# never fetched. bc3's open tier, and the per-domain row quota it needs, aren't
# ported.
#
# - Url:      strict identifier validation, with no normalization
# - Fetcher:  the SSRF-guarded HTTP fetch and its caching arithmetic
# - Document: JSON validation and mapping to client attributes
# - Resolver: lookup, fetch and persist, for the authorization endpoint
module Oauth::ClientMetadata
  extend self

  # Exact host match: the allowlist names hosts, not domains, so a subdomain of
  # an allowed host isn't allowed.
  def recognized?(client_id)
    host = Url.host(client_id)
    host.present? && allowed_hosts.include?(host)
  end

  def allowed_hosts
    Array(Rails.application.config.x.oauth.cimd_allowed_hosts)
  end
end
