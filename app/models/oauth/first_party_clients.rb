# Canonical registry of the OAuth clients Fizzy ships with, as bc3's
# Oauth::FirstPartyClients is for Basecamp. Development seeds and operator
# provisioning both draw from here, so the two can't drift:
#
#   bin/rails oauth:provision_first_party_clients
#
# Provisioning is idempotent and total: each definition is merged over an
# explicit security-policy BASELINE, so drift in any policy attribute a
# definition doesn't name (a hand-flipped trusted, a stray redirect, a secret
# on a public row) is reset on every converge. The batch runs in one
# transaction: either every client converges or none does.
#
# Two things a converge never does. It never mints or rotates a secret: a
# confidential client's secret comes only from oauth:mint_client_secret, and
# one left without a secret is reported for that, not given one. And it never
# turns a client back on. Fizzy has no disabled flag; a hosted MCP client is
# turned off by dropping its resource from FIZZY_OAUTH_MCP_RESOURCES, or by
# clearing its secret. The first leaves it outside every converge here, and
# the second is kept, since the secret is never written.
module Oauth::FirstPartyClients
  # Every policy attribute an oauth_clients row carries, at its standard
  # value. Definitions list only their deliberate deltas; omission means
  # this, never whatever the row happens to hold. The metadata cache columns
  # belong to Client ID Metadata Documents, which no first-party client is.
  #
  # client_secret_digest is nil here so a public row loses any stray secret;
  # a confidential row's is dropped from the merge (see converge!), so a live
  # secret survives.
  BASELINE = {
    token_endpoint_auth_method: "none",
    client_secret_digest: nil,
    redirect_uris: [],
    scopes: [],
    trusted: false,
    dynamically_registered: false,
    client_id_metadata_document: false,
    metadata_etag: nil,
    metadata_expires_at: nil,
    metadata_fetched_at: nil,
    protected_resource: nil
  }.freeze

  # The issuer of personal access tokens (Oauth::Client.personal_access_issuer).
  # It is listed for no grant type, so nothing but My::AccessTokensController
  # mints its tokens.
  PERSONAL_ACCESS = { name: "Personal Access Tokens", trusted: true, scopes: %w[ read write ] }.freeze

  # The MCP servers 37signals hosts, by the resource each fronts, with the
  # client its deployment exchanges tokens through (FIZZY_MCP_EXCHANGE_CLIENT_ID).
  # Production and the betas share one database, so each MCP server has a
  # client of its own.
  #
  # Each converges only where FIZZY_OAUTH_MCP_RESOURCES names its resource,
  # which is also the only place its client can exchange tokens
  # (Oauth::Client#delegation_client?). So production's converge never
  # writes a beta's row, nor a beta's production's, and an install that
  # configures neither, such as development or a self-hosted one, gets
  # neither. An MCP server not listed here is provisioned by
  # oauth:provision_mcp_client.
  HOSTED_MCP_SERVERS = {
    "https://mcp.fizzy.do/mcp" => Oauth::Client::MCP_CLIENT_ID,
    "https://beta1-mcp.fizzy-beta.com/mcp" => "fizzy-mcp-server-beta1"
  }.freeze

  class << self
    def provision!
      converge! definitions
    end

    # The clients this install should hold, given the MCP resources it serves.
    def definitions(resources = Oauth.mcp_resources)
      mcp_servers = HOSTED_MCP_SERVERS.slice(*resources).to_h { |resource, client_id| [ client_id, mcp_server(resource) ] }

      { Oauth::Client::PERSONAL_ACCESS_CLIENT_ID => PERSONAL_ACCESS }.merge(mcp_servers)
    end

    # The attributes a definition converges a client to.
    def attributes_for(client_id)
      BASELINE.merge definitions.fetch(client_id)
    end

    # A confidential client that can't authenticate until
    # oauth:mint_client_secret gives it a secret: one never minted, or one
    # whose secret was cleared. Either has no digest, run after run.
    def awaiting_secret?(client)
      client.confidential? && client.client_secret_digest.blank?
    end

    # One MCP server's client, outside the hosted registry, by the client_id
    # its deployment names (oauth:provision_mcp_client). A hosted resource and
    # a beta's client stay paired: neither can be provisioned under another's
    # name. Any other server may take fizzy-mcp-server, the default, named or
    # not; converge! keeps it off production's row wherever that exists.
    def provision_mcp_server!(resource, client_id: nil)
      hosted_client_id = HOSTED_MCP_SERVERS[resource]
      client_id ||= hosted_client_id || Oauth::Client::MCP_CLIENT_ID
      hosted_resource = HOSTED_MCP_SERVERS.key(client_id) unless client_id == Oauth::Client::MCP_CLIENT_ID

      if (hosted_client_id && hosted_client_id != client_id) || (hosted_resource && hosted_resource != resource)
        raise ArgumentError, "#{resource} and #{client_id} aren't a hosted pair; hosted MCP servers converge with oauth:provision_first_party_clients"
      else
        converge!(client_id => mcp_server(resource)).sole
      end
    end

    # Each client fronts one resource, so an MCP client already fronting
    # another resource is refused rather than repointed, which would strand
    # every grant audienced to that resource, when that resource is still
    # configured here or is a hosted one. Production and the betas share a
    # database, and each configures only its own resource, so a hosted row is
    # never safe to move from any of them. Any other client whose resource
    # has been dropped from the configuration may move.
    #
    # The model gives a new confidential client a throwaway secret nobody
    # holds. A registry client gets none instead, so that awaiting_secret?
    # reports it until oauth:mint_client_secret gives it one.
    def converge!(definitions)
      Oauth::Client.transaction do
        definitions.map do |client_id, definition|
          client = Oauth::Client.find_or_initialize_by(client_id: client_id)
          attributes = BASELINE.merge(definition)

          if attributes[:token_endpoint_auth_method].in?(Oauth::Client::SECRET_AUTH_METHODS)
            attributes.delete(:client_secret_digest)
          end

          if attributes[:protected_resource] && client.protected_resource != attributes[:protected_resource] && fronting_for_good?(client)
            raise ArgumentError, "#{client_id} already fronts #{client.protected_resource}; give #{attributes[:protected_resource]} a client of its own"
          else
            client.update! attributes
            client.update_columns client_secret_digest: nil if client.previously_new_record? && client.confidential?
            client
          end
        end
      end
    end

    private
      def fronting_for_good?(client)
        client.delegation_client? || HOSTED_MCP_SERVERS.key?(client.protected_resource)
      end

      def mcp_server(resource)
        { name: "Fizzy MCP server", token_endpoint_auth_method: "client_secret_post", scopes: %w[ read write ], protected_resource: resource }
      end
  end
end
