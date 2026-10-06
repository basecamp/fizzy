# OAuth spec conformance and Basecamp parity

This covers Fizzy's OAuth authorization server (AS) and the API acting as resource
server. It records, for each requirement, whether we conform, where a fix landed,
where it is planned, or why we deliberately depart from it. Basecamp's AS (bc3) is
the reference for parity. Where bc3 has a gap of its own, we don't copy it.

Snapshot: 2026-10-06, at the heads of the OAuth train, rebased onto main:

| PR | Branch | Scope |
|----|--------|-------|
| [#2296](https://github.com/basecamp/fizzy/pull/2296) | `oauth` | Code + PKCE, discovery, DCR (loopback), revocation, Connected Apps, availability switches |
| [#3080](https://github.com/basecamp/fizzy/pull/3080) | `oauth-dcr-https` | DCR with https redirects |
| [#3081](https://github.com/basecamp/fizzy/pull/3081) | `oauth-refresh-tokens` | 1h access-token expiry, refresh rotation |
| [#3082](https://github.com/basecamp/fizzy/pull/3082) | `oauth-confidential-clients` | `client_secret_post` and `client_secret_basic`; client authentication at revocation |
| [#3158](https://github.com/basecamp/fizzy/pull/3158) | `oauth-bearer-challenge` | Resource-server Bearer challenge (on #3082) |
| [#3160](https://github.com/basecamp/fizzy/pull/3160) | `oauth-refresh-replay` | Refresh-token replay detection (on #3082) |
| [#3161](https://github.com/basecamp/fizzy/pull/3161) | `oauth-grant-idle-expiry` | 90-day idle expiry of grants (on #3160) |
| [#3159](https://github.com/basecamp/fizzy/pull/3159) | `oauth-client-sweep` | Sweep of abandoned DCR clients (on #3161) |

Commits are cited by subject, with the short SHA as of the snapshot. Rebases change
the SHAs of #3080 and above; the subjects stay the same.

The hosted MCP plan is
[fizzy-mcp-server#5 `docs/hosted-plan.md`](https://github.com/basecamp/fizzy-mcp-server/pull/5).
Its phases (A merge dark; B audience + account binding; C RFC 8693 exchange; C′ DPoP
and CIMD; D–G MCP server and light-up) are what "Planned" refers to below.

Status key:

- **Conformant**: holds at the snapshot, with no change needed in this round.
- **Fixed**: the PR and commit that made it hold.
- **Planned**: not built yet; names the hosted-plan phase.
- **Deliberate**: a recorded posture, with the reason given.
- **Open decision**: a departure that needs a call (see [Decisions](#decisions)).
- **N/A**: does not apply to Fizzy.

## Availability (ship dark)

| Requirement | Status |
|---|---|
| The AS merges dark: discovery, DCR, authorize and token answer 404 unless `OAUTH_ACCEPTANCE_ENABLED=true`; OAuth bearer tokens are refused while dark; personal access tokens are unaffected (hosted plan, Phase A and Decision 6) | **Fixed** #2296 `1183b2bee` "Ship the OAuth authorization server dark behind availability switches". Port of bc3's `Oauth::Availability`. |
| Issuance can be paused (`OAUTH_ISSUANCE_ENABLED=false`) while existing tokens are still honored; minting and refresh answer 503 | **Fixed** #2296 `1183b2bee`; refresh covered in #3081 `34ed3b580` |
| Pilot client ids are exempt by exact `client_id`; registration can't be used to claim a pilot id | **Fixed** #2296 `1183b2bee`, `9a9d3ce7a` "Keep registration dark when a request names a pilot client" |
| Revocation, Connected Apps and consent denial are never gated, so people can always shed access | **Conformant** (by design in `Oauth::Availability`) |
| Unset means dark, which differs from bc3's dev default; dark answers 404 where bc3 answers 503; protected-resource metadata is also 404 while dark | **Deliberate**. Fizzy has no other AS to name, and OSS installs that never mention OAuth must look like they have none. |

## RFC 6749 / OAuth 2.1: authorization endpoint

| Requirement | Status |
|---|---|
| `response_type=code` only | **Conformant** |
| PKCE required, `S256` only (OAuth 2.1 §4.1.1, RFC 7636) | **Conformant** |
| Exact `redirect_uri` match against the registered list; never redirect to an unregistered URI (§3.1.2, §4.1.2.1) | **Conformant** |
| Loopback redirects: only the port may vary, host and query must match exactly, http only (RFC 8252 §7.3) | **Fixed** #2296 `51155c5e3` "…vary only the loopback port" (exact host and query; restores a fix a resolved Copilot thread had recorded as done but that was lost), `771ed906d` "Vary the port only for http loopback redirects"; #3080 `ff7d3a0b9` (no port variance onto a fragment), `54ae99d3a` |
| `state` is required | **Deliberate**. Stricter than OAuth 2.1 with PKCE. Kept. |
| Consent is CSRF-protected (§10.12) | **Conformant**. The app-wide Origin check (`forgery_protection_origin_check`) refuses same-site sibling origins as well as cross-site ones. A finding that it didn't was refuted. |
| Consent is always shown; `trusted` doesn't skip it | **Deliberate** (#2296 body) |
| CSP `form-action` lets the consent POST redirect to the validated redirect origin; Chrome had been stranding the flow | **Fixed** #2296 `d468283d7` "Let consent redirect past CSP…". Ported from bc3. Covered by a Chrome system test (`test/system/oauth_consent_test.rb`). |
| Canonical scope: "Read + Write" is `read write`; a `read write` request preselects it instead of silently downgrading to read | **Fixed** #2296 `d468283d7`; refresh reports the same string in #3081 `1649f431a` |

## RFC 6749 / OAuth 2.1: token endpoint

| Requirement | Status |
|---|---|
| Authorization codes are single-use; reuse is refused and the grant minted from that code is revoked (§4.1.2, §10.5; OAuth 2.1 §4.1.3) | **Fixed** #2296 `bd447dd7a` "Redeem each authorization code once…". A `jti` in the code plus a unique `identity_access_tokens.authorization_code_jti`. Reuse is checked only after PKCE, `redirect_uri` and `client_id` pass, so a leaked code without its verifier can't revoke the grant. Limit: if the grant is revoked within the code's 60s life, the row is gone and one more redemption is possible. No tombstones were added. |
| `client_id` required and matched to the code for public clients (§4.1.3) | **Fixed** #2296 `bd447dd7a`; one check shared by both grants in #3081 `ef68e02e9` |
| Missing or malformed parameters answer `invalid_request`, not `invalid_grant` or `unsupported_grant_type` (§5.2) | **Fixed** #2296 `bd447dd7a`, `ac884df5f` "Reject non-string token request parameters as malformed" (an array `refresh_token` had been accepted as an `IN` list; a hash had raised a 500); #3081 `ef68e02e9`, `2adf1c1ac` |
| Exact `redirect_uri` equality with the code (§4.1.3) | **Conformant** |
| Responses, errors included, carry `Cache-Control: no-store` (§5.1) | **Fixed** #3082 `d757ad472`, `4ef4072aa` (`prevent_caching` is now a before_action, so halted chains are covered too) |
| A confidential client authenticates before anything about the grant is looked up, so a wrong secret reveals nothing about whether a code or refresh token is live | **Fixed** #3082 `17555fe19`, `4ef4072aa` "Authenticate the named client before resolving the grant…" |
| A client that fails authentication gets 401 `invalid_client`, with `WWW-Authenticate: Basic` only when the request carried an Authorization header (§5.2) | **Fixed** #3082 `3ab7d9fa0` "Name the Basic scheme only to a client that tried the Authorization header". The same at the token endpoint and revocation, and the same as bc3 (bc3#13678). A body-only failure gets no challenge. |
| Client credentials are read from the request body only, never the query string | **Conformant** (#3082 `2fcc742d7`) |
| Per-IP rate limit of 20/min on the token endpoint | **Conformant**. A per-client budget after confidential authentication is **Planned** (Phase C); the per-IP limit blocks hosted use. |

## RFC 6749 §2.3.1: client authentication

| Requirement | Status |
|---|---|
| `client_secret_post` | **Conformant** (#3082) |
| HTTP Basic (`client_secret_basic`) MUST be supported for clients issued a password; a failed Basic attempt gets 401 + `WWW-Authenticate` (§5.2) | **Fixed** #3082 `a8b635fa4` "Accept client_secret_basic at the token endpoint". Either method authenticates any confidential client; both at once is `invalid_request`. DCR and metadata advertise it. bc3 closes the same gap in bc3#13678. |
| Secrets stored in plaintext, as access tokens are | **Deliberate** (#3082 body) |

## Refresh tokens (RFC 6749 §6, OAuth 2.1 §4.3, RFC 9700 §4.14)

| Requirement | Status |
|---|---|
| Rotation on every refresh, atomic (compare-and-swap); a concurrent loser gets `invalid_grant` | **Conformant** (#3081) |
| Refresh may narrow scope, never widen it; blank or `null` scope is refused | **Conformant** (#3081 `b3edc8dc8`, `7da895620`, `a45190e93`) |
| `client_id` required and must match the grant | **Conformant** (#3081 `ef68e02e9`) |
| Public clients' refresh tokens MUST be sender-constrained, or rotated **with replay detection**: presenting a rotated-out token revokes the live one (OAuth 2.1 §4.3.1, RFC 9700 §4.14.2) | **Fixed** #3160 `2b3061158` "Revoke the grant when a rotated refresh token is replayed, with a retry grace". A replay revokes the grant. A retry within 60s, while the successor is still current, gets that successor, as in bc3. |
| Refresh tokens SHOULD expire after client inactivity (RFC 9700 §4.14.2) | **Fixed** #3161 `3d624cda8` "Lapse OAuth grants left idle for 90 days", `5e40b3d10`. This matches bc3's 90-day `refresh_token_ttl`. A grant that lapses restarts its client's 30-day sweep clock (#3159). |

## RFC 7009: revocation

| Requirement | Status |
|---|---|
| Revokes an access or refresh token, destroying the whole grant; always 200 for unknown tokens (§2.2) | **Conformant** |
| Missing token answers `invalid_request` JSON (§2.2.1) | **Fixed** #2296 `51155c5e3` |
| Confidential clients authenticate, and the token must have been issued to the requesting client (§2.1) | **Fixed** #3082 `6ddebd19f` "Authenticate clients at revocation and revoke only their own tokens". A public client names its `client_id`. Unknown tokens, and tokens belonging to another client, get 200 and nothing is revoked. |
| A presented client secret that authenticates no client is refused with 401, whatever the token | **Deliberate**, and stricter than bc3: #3082 `4ca622d24`, `b57456501`. A 200 would tell a client with a mistyped `client_id` that a live grant was dead. bc3 is being aligned to this. |
| A personal access token can be revoked here by whoever holds it. It has no client, so holding it is the credential; client credentials sent alongside must still authenticate | **Fixed** #3082 `8947b420a` "Revoke personal access tokens at the revocation endpoint again". Revocation works the same for every kind of token, which helps incident response such as revoking a leaked token. It also keeps the endpoint ready if personal access tokens become OAuth tokens, as in bc3. |
| No rate limit | **Deliberate**. The endpoint isn't an oracle and the token space can't be guessed. |

## RFC 8414 / RFC 9728: metadata

| Requirement | Status |
|---|---|
| Issuer, endpoints, grant types, PKCE methods and scopes advertised | **Conformant** |
| `revocation_endpoint_auth_methods_supported` matches behaviour (`["none", "client_secret_post", "client_secret_basic"]`; an omitted value would mean `client_secret_basic` alone) | **Fixed** #2296 `51155c5e3`; #3082 `6ddebd19f` |
| `response_modes_supported: ["query"]` (an omitted value implies fragment, which is unsupported) | **Fixed** #2296 `51155c5e3`. Unknown `response_mode` is ignored, per RFC 6749 §3.1, not rejected. |
| `token_endpoint_auth_methods_supported` matches behaviour | **Conformant** (`none`, `client_secret_post`, `client_secret_basic`) |
| RFC 9728 protected-resource metadata | **Conformant** (#2296). It has one app-wide resource; MCP resources come in Phase B. |

## RFC 9207: issuer in the authorization response

| Requirement | Status |
|---|---|
| `iss` on success and error redirects, equal to the metadata issuer; `authorization_response_iss_parameter_supported: true` (mix-up defense, RFC 9700 §4.4) | **Fixed** #2296 `d468283d7`. A single `Oauth::BaseController#oauth_issuer` feeds both the redirect and the metadata. |

## RFC 9700: open redirector

| Requirement | Status |
|---|---|
| Never auto-redirect errors to an untrusted URI (§4.11.2). Self-registered https hosts get the local error page for pre-consent errors; operator clients and loopback still redirect; deny after consent still redirects | **Fixed** #3080 `0d722d05d` "Render pre-consent errors here for self-registered https clients", `d56b245e9` (tests for every pre-consent error) |

## RFC 7591: dynamic client registration

| Requirement | Status |
|---|---|
| Loopback and https redirect URIs; fragments, plain-http public hosts and custom schemes rejected | **Conformant** (#2296, #3080) |
| A self-registered redirect names its authority plainly: no userinfo, no percent-encoded host, a port from 1 to 65535. Consent names a non-default port, and loopback port variation keeps userinfo fixed | **Fixed** #3080 `64cb8a019` "Register only redirects whose authority is plain, and show their port on consent". One rule at registration, in place of canonicalizing wherever the URI is shown or compared |
| Errors answer `invalid_client_metadata` or `invalid_redirect_uri`, never 500 (§3.2.2). An over-long or non-String `client_name` had raised a 500 on both databases | **Fixed** #2296 `51155c5e3` |
| Open, unauthenticated registration of any https host (no initial access token, no host vetting) | **Deliberate** (#3080, hosted plan): Cursor and other generic MCP clients need it. bc3 vets hosts; Fizzy will cover the recognized-host tier with CIMD (Phase C′). Impersonating names on consent go to the consent design pass (D5). |
| Abandoned registrations are reclaimed (§5 abuse mitigation) | **Fixed** #3159 `f8c1a552d`, `ba2142af4`. A daily sweep removes self-registered clients with no grant activity for 30 days, matching bc3's retention. It row-locks and shares that lock with issuance, so it can't race a code exchange. Under the lock it rechecks the whole stale test, and consent touches the client, so a client isn't swept between consent and its code exchange (`14a777ce2`). A refresh whose client row is gone gets a 400, not a 500. Groundwork in #2296 `65e4d3e7c` fixed the `access_tokens` association and a schema-only foreign key that migrated databases never had. |
| RFC 7592 management endpoint, initial access token, global registration cap | **Deliberate**: not built. RFC 7592 is optional. A global cap would turn one actor's abuse into an outage for everyone. |

## RFC 6750 / RFC 9110: resource-server challenge

| Requirement | Status |
|---|---|
| Challenges use the `Bearer` scheme (§3). Rails' default was `Token realm=` | **Fixed** #3158 `a40de58ed` "Answer API authentication failures with a Bearer challenge" |
| A presented but invalid or expired token gets 401 `error="invalid_token"` (§3.1); clients refresh on this hourly since #3081 | **Fixed** #3158 `a40de58ed` |
| A valid read token on a write gets 403 `error="insufficient_scope", scope="write"`, so clients stop refreshing in a loop | **Fixed** #3158 `a40de58ed` |
| A JSON request with no credentials gets 401 plus a challenge instead of a 302 to sign-in (§3) | **Fixed** #3158, except for requests carrying a session cookie or `X-Requested-With`, which keep the 302 so in-app autosave and uploads don't break. **Open decision**: D6. |
| The scheme is matched case-insensitively (RFC 9110 §11.1) | **Fixed** #3158 `a40de58ed` |
| `resource_metadata` in the challenge (RFC 9728 §5.1), omitted while dark | **Fixed** #3158 `a40de58ed` |
| A Bearer header on an HTML request: 401, not the SHOULD-level 400 for `invalid_request` | **Deliberate** (#3158 summary); preserves the existing refusal. |

## Parity with bc3 not yet built

| Capability | Status |
|---|---|
| RFC 8707 resource indicators and audience stamping; the API refuses audienced tokens | **Planned**: Phase B. The `resource` parameter is ignored today, which RFC 6749 §3.1 permits. Must ship before any MCP-audienced token is issued. |
| One account per connection (account-bound grants, account picker at consent) | **Planned**: Phase B, Decision 4. OAuth tokens are identity-wide today, like personal access tokens. |
| RFC 8693 token exchange for the MCP server | **Planned**: Phase C, on top of B. Copy bc3's error table. |
| Per-client token rate limit after confidential authentication | **Planned**: Phase C |
| DPoP-bound delegated tokens, replay store (port the bc3#12535 fix), `htu` behind kamal-proxy | **Planned**: Phase C′. #3158 already parses the scheme, so the DPoP branch can reuse it. The binding check must be keyed on the token row, not on the header. |
| CIMD (URL client ids, recognized hosts, SSRF-guarded via Surfguard) | **Planned**: Phase C′, after DPoP |
| Device authorization grant (RFC 8628) | **N/A for now**: there's no consumer. fizzy-cli uses personal access tokens, and a CLI can use a loopback redirect with PKCE. Revisit if fizzy-cli moves to OAuth login. |
| Token introspection (RFC 7662) | **N/A**: exchange is the chosen model. |

## Decisions

These need Jeremy. Everything else above is either conformant, fixed in the
train, or planned.

D1 through D4 were decided and are built: replay detection (#3160), idle
expiry (#3161), `client_secret_basic` (#3082), and client authentication at
revocation (#3082). For D4, personal access tokens stay revocable by whoever
holds them, and a client secret that authenticates no client gets 401.

5. **D5: consent for self-registered clients.** For the consent design pass:
   lead with the redirect host rather than the self-asserted `client_name`, and
   refuse impersonating names (Fizzy, Basecamp, HEY, Claude, ChatGPT) for
   self-registered clients.
6. **D6: rule for the no-credentials 401 (#3158).** A JSON request with no
   session cookie and no `X-Requested-With` gets 401 + Bearer; anything else
   keeps the 302, so in-app autosave isn't sent to the challenge URL by
   `@rails/request.js`. An API client that sends `X-Requested-With` without
   credentials still gets a 302. Accept this rule, or narrow it?

The train is rebased onto main, which carries rubyzip 3.7.0, so the Security
audit no longer flags rubyzip 3.3.0 (CVE-2026-85396).
