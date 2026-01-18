# Fizzy OAuth 2.1 + MCP

OAuth for Fizzy. One table, one column, a handful of small controllers. MCP support included.

---

## The Insight

Fizzy's `Identity::AccessToken` is already perfect:

```ruby
class Identity::AccessToken < ApplicationRecord
  belongs_to :identity
  has_secure_token
  enum :permission, %w[ read write ].index_by(&:itself), default: :read

  def allows?(method)
    method.in?(%w[ GET HEAD ]) || write?
  end
end
```

**10 lines.** Don't replace it. Extend it.

---

## What We Add

| Addition | Type | Purpose |
|----------|------|---------|
| `oauth_clients` | table | Client registry (MCP DCR, first-party) |
| `oauth_client_id` | column | Links access tokens to OAuth clients |

That's it. One table. One column.

- **PATs stay PATs** — tokens with `oauth_client_id = nil`
- **OAuth tokens are PATs with a client** — `oauth_client_id` is set
- **Bearer auth works unchanged** — the `Authentication` concern already uses `Identity::AccessToken`

---

## Authorization Codes: Stateless

No table. Rails primitives only.

```ruby
module Oauth::AuthorizationCode
  Details = Data.define(:client_id, :identity_id, :code_challenge, :redirect_uri, :scope)

  class << self
    def generate(client_id:, identity_id:, code_challenge:, redirect_uri:, scope:)
      encryptor.encrypt_and_sign(
        { c: client_id, i: identity_id, h: code_challenge, r: redirect_uri, s: scope },
        expires_in: 60.seconds
      )
    end

    def parse(code)
      return nil if code.blank?
      data = encryptor.decrypt_and_verify(code)
      return nil if data.nil?
      Details.new(
        client_id: data["c"],
        identity_id: data["i"],
        code_challenge: data["h"],
        redirect_uri: data["r"],
        scope: data["s"]
      )
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    def valid_pkce?(code_data, code_verifier)
      return false if code_data.nil? || code_verifier.blank?
      expected = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
      ActiveSupport::SecurityUtils.secure_compare(expected, code_data.code_challenge)
    end

    private
      def encryptor
        @encryptor ||= ActiveSupport::MessageEncryptor.new(
          Rails.application.key_generator.generate_key("oauth/authorization_codes", 32)
        )
      end
  end
end
```

- 60-second TTL + PKCE-bound
- No database = no cleanup job

---

## Grants: Implicit

No `oauth_authorizations` table.

A "grant" is just "a token exists for this client + identity." Revocation = delete tokens.

"Connected Apps" UI at `/my/connected_apps`:

```ruby
# List apps
current_identity.access_tokens.where.not(oauth_client: nil).includes(:oauth_client).group_by(&:oauth_client)

# Disconnect an app (revoke all tokens for that client)
current_identity.access_tokens.where(oauth_client: client).destroy_all
```

---

## Scopes

OAuth scopes are space-delimited (e.g., `"read write"`). We map to `Identity::AccessToken#permission`:

- If `"write"` is in the scope list → `permission: "write"`
- Otherwise → `permission: "read"`

The token response returns the granted scopes as a space-delimited string.

---

## Token Lifetime

Access tokens **do not expire**. This matches PAT behavior and keeps the implementation simple:

- No refresh tokens needed
- No background jobs to clean up expired tokens
- Revocation is explicit: via `/oauth/revocation` endpoint or "Connected Apps" UI

If expiration is needed later, add an `expires_at` column to `identity_access_tokens` and return `expires_in` in the token response. The revocation endpoint already handles cleanup.

---

## Routes

```ruby
get "/.well-known/oauth-authorization-server", to: "oauth/metadata#show"
get "/.well-known/oauth-protected-resource", to: "oauth/protected_resource_metadata#show"

namespace :oauth do
  resources :clients, only: :create          # POST /oauth/clients (DCR)
  resource :authorization, only: %i[ new create ]  # GET/POST /oauth/authorization
  resource :token, only: :create             # POST /oauth/token
  resource :revocation, only: :create        # POST /oauth/revocation
end
```

Two well-known endpoints for discovery. Singular resources for OAuth protocol endpoints. Plural for the client registry.

---

## Redirect URI Matching

Per RFC 8252, loopback clients get port flexibility:

- Registered: `http://127.0.0.1:8888/callback`
- Allowed: `http://127.0.0.1:9999/callback` (different port, same path)
- Allowed: `http://localhost:7777/callback` (different loopback host)

Non-loopback clients require exact string match.

DCR clients are restricted to loopback URIs only (http, not https).

---

## Security

- **Short-lived, PKCE-bound codes**: 60 seconds, S256 only
- **Loopback-only DCR**: MCP clients must use `127.0.0.1`, `localhost`, or `[::1]`
- **PKCE required**: no "plain" method
- **Port-flexible loopback matching**: per RFC 8252
- **Rate limited**: DCR (10/min), token exchange (20/min)

---

## Standards

- RFC 6749 (OAuth 2.0)
- RFC 6750 (Bearer tokens)
- RFC 7636 (PKCE, S256 only)
- RFC 7591 (DCR subset)
- RFC 8414 (AS Discovery)
- RFC 8252 (Loopback redirects)
- RFC 9728 (Protected Resource Metadata)

---

## Why This Over "Proper OAuth"

| "Proper" OAuth | This |
|----------------|------|
| 4 tables | 1 table + 1 column |
| Migrate PATs | PATs stay |
| Stored auth codes | Stateless |
| Explicit grant table | Implicit |
| ~600 lines | ~350 lines |

Both are correct. This one is half the code.
