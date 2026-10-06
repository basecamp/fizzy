# OAuth spec conformance and Basecamp parity

This covers Fizzy's OAuth authorization server (AS) and the API acting as resource
server. It records, for each requirement, whether we conform, where a fix landed,
where it is planned, or why we deliberately depart from it. Basecamp's AS (bc3) is
the reference for parity. Where bc3 has a gap of its own, we don't copy it.

Snapshot: 2026-10-05, at the heads of the OAuth train plus the two PRs above it:

| PR | Branch | Scope |
|----|--------|-------|
| [#2296](https://github.com/basecamp/fizzy/pull/2296) | `oauth` | Code + PKCE, discovery, DCR (loopback), revocation, Connected Apps, availability switches |
| [#3080](https://github.com/basecamp/fizzy/pull/3080) | `oauth-dcr-https` | DCR with https redirects |
| [#3081](https://github.com/basecamp/fizzy/pull/3081) | `oauth-refresh-tokens` | 1h access-token expiry, refresh rotation |
| [#3082](https://github.com/basecamp/fizzy/pull/3082) | `oauth-confidential-clients` | `client_secret_post` |
| [#3158](https://github.com/basecamp/fizzy/pull/3158) | `oauth-bearer-challenge` | Resource-server Bearer challenge (on #3082) |
| [#3159](https://github.com/basecamp/fizzy/pull/3159) | `oauth-client-sweep` | Sweep of abandoned DCR clients (on #3082) |

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
| The AS merges dark: discovery, DCR, authorize and token answer 404 unless `OAUTH_ACCEPTANCE_ENABLED=true`; OAuth bearer tokens are refused while dark; personal access tokens are unaffected (hosted plan, Phase A and Decision 6) | **Fixed** #2296 `2b6ea648e` "Ship the OAuth authorization server dark behind availability switches". Port of bc3's `Oauth::Availability`. |
| Issuance can be paused (`OAUTH_ISSUANCE_ENABLED=false`) while existing tokens are still honored; minting and refresh answer 503 | **Fixed** #2296 `2b6ea648e`; refresh covered in #3081 `56619d688` |
| Pilot client ids are exempt by exact `client_id`; registration can't be used to claim a pilot id | **Fixed** #2296 `2b6ea648e`, `bf477a748` "Keep registration dark when a request names a pilot client" |
| Revocation, Connected Apps and consent denial are never gated, so people can always shed access | **Conformant** (by design in `Oauth::Availability`) |
| Unset means dark, which differs from bc3's dev default; dark answers 404 where bc3 answers 503; protected-resource metadata is also 404 while dark | **Deliberate**. Fizzy has no other AS to name, and OSS installs that never mention OAuth must look like they have none. |

## RFC 6749 / OAuth 2.1: authorization endpoint

| Requirement | Status |
|---|---|
| `response_type=code` only | **Conformant** |
| PKCE required, `S256` only (OAuth 2.1 §4.1.1, RFC 7636) | **Conformant** |
| Exact `redirect_uri` match against the registered list; never redirect to an unregistered URI (§3.1.2, §4.1.2.1) | **Conformant** |
| Loopback redirects: only the port may vary, host and query must match exactly, http only (RFC 8252 §7.3) | **Fixed** #2296 `96fc38053` "…vary only the loopback port" (exact host and query; restores a fix a resolved Copilot thread had recorded as done but that was lost), `8eadf7b13` "Vary the port only for http loopback redirects"; #3080 `44a25ab0c` (no port variance onto a fragment), `d154d6fea` |
| `state` is required | **Deliberate**. Stricter than OAuth 2.1 with PKCE. Kept. |
| Consent is CSRF-protected (§10.12) | **Conformant**. The app-wide Origin check (`forgery_protection_origin_check`) refuses same-site sibling origins as well as cross-site ones. A finding that it didn't was refuted. |
| Consent is always shown; `trusted` doesn't skip it | **Deliberate** (#2296 body) |
| CSP `form-action` lets the consent POST redirect to the validated redirect origin; Chrome had been stranding the flow | **Fixed** #2296 `83e9118e7` "Let consent redirect past CSP…". Ported from bc3. Covered by a Chrome system test (`test/system/oauth_consent_test.rb`). |
| Canonical scope: "Read + Write" is `read write`; a `read write` request preselects it instead of silently downgrading to read | **Fixed** #2296 `83e9118e7`; refresh reports the same string in #3081 `ad9241137` |

## RFC 6749 / OAuth 2.1: token endpoint

| Requirement | Status |
|---|---|
| Authorization codes are single-use; reuse is refused and the grant minted from that code is revoked (§4.1.2, §10.5; OAuth 2.1 §4.1.3) | **Fixed** #2296 `bac77f7d6` "Redeem each authorization code once…". A `jti` in the code plus a unique `identity_access_tokens.authorization_code_jti`. Reuse is checked only after PKCE, `redirect_uri` and `client_id` pass, so a leaked code without its verifier can't revoke the grant. Limit: if the grant is revoked within the code's 60s life, the row is gone and one more redemption is possible. No tombstones were added. |
| `client_id` required and matched to the code for public clients (§4.1.3) | **Fixed** #2296 `bac77f7d6`; one check shared by both grants in #3081 `2677d0092` |
| Missing or malformed parameters answer `invalid_request`, not `invalid_grant` or `unsupported_grant_type` (§5.2) | **Fixed** #2296 `bac77f7d6`, `1402fa7dd` "Reject non-string token request parameters as malformed" (an array `refresh_token` had been accepted as an `IN` list; a hash had raised a 500); #3081 `2677d0092`, `29b65b3ad` |
| Exact `redirect_uri` equality with the code (§4.1.3) | **Conformant** |
| Responses, errors included, carry `Cache-Control: no-store` (§5.1) | **Fixed** #3082 `4ea9d73e4`, `e17b6d298` (`prevent_caching` is now a before_action, so halted chains are covered too) |
| A confidential client authenticates before anything about the grant is looked up, so a wrong secret reveals nothing about whether a code or refresh token is live | **Fixed** #3082 `03524fe53`, `e17b6d298` "Authenticate the named client before resolving the grant…" |
| A confidential client that fails authentication gets `invalid_client` | **Conformant** (#3082). It answers with a 400, not a 401, because there is no Authorization-header scheme to challenge with. **Deliberate** (comment in `TokensController#authenticate_client`). |
| Client credentials are read from the request body only, never the query string | **Conformant** (#3082 `9cb3e35c0`) |
| Per-IP rate limit of 20/min on the token endpoint | **Conformant**. A per-client budget after confidential authentication is **Planned** (Phase C); the per-IP limit blocks hosted use. |

## RFC 6749 §2.3.1: client authentication

| Requirement | Status |
|---|---|
| `client_secret_post` | **Conformant** (#3082) |
| HTTP Basic (`client_secret_basic`) MUST be supported for clients issued a password; a failed Basic attempt gets 401 + `WWW-Authenticate` (§5.2) | **Open decision**: D3. #3082 deliberately supports post only, and DCR rejects `client_secret_basic`. Metadata is consistent with that, so the behaviour is honest, but it misses the MUST. bc3 has the same gap. The fix is additive at the train tip and needs no migration. |
| Secrets stored in plaintext, as access tokens are | **Deliberate** (#3082 body) |

## Refresh tokens (RFC 6749 §6, OAuth 2.1 §4.3, RFC 9700 §4.14)

| Requirement | Status |
|---|---|
| Rotation on every refresh, atomic (compare-and-swap); a concurrent loser gets `invalid_grant` | **Conformant** (#3081) |
| Refresh may narrow scope, never widen it; blank or `null` scope is refused | **Conformant** (#3081 `042825ffa`, `3cb021820`, `77ed409c0`) |
| `client_id` required and must match the grant | **Conformant** (#3081 `2677d0092`) |
| Public clients' refresh tokens MUST be sender-constrained, or rotated **with replay detection**: presenting a rotated-out token revokes the live one (OAuth 2.1 §4.3.1, RFC 9700 §4.14.2) | **Open decision**: D1. Today a replayed rotated token fails as unknown and the live grant survives. The #3081 body records this as deliberate. bc3 revokes the token family, with a 60s replay grace. |
| Refresh tokens SHOULD expire after client inactivity (RFC 9700 §4.14.2) | **Open decision**: D2. Grants currently live until revoked (#3081 body). bc3 uses a 90-day `refresh_token_ttl`. |

## RFC 7009: revocation

| Requirement | Status |
|---|---|
| Revokes an access or refresh token, destroying the whole grant; always 200 for unknown tokens (§2.2) | **Conformant** |
| Missing token answers `invalid_request` JSON (§2.2.1) | **Fixed** #2296 `96fc38053` |
| Confidential clients authenticate, and the token must have been issued to the requesting client (§2.1) | **Open decision**: D4. Revocation is unauthenticated by design (#3082 body: holding the token is the capability). One review thread is open on it: [#3082 r4190956123](https://github.com/basecamp/fizzy/pull/3082#discussion_r4190956123). |
| A personal access token can be revoked here by whoever holds it | **Deliberate**. It helps incident response, for example secret scanners revoking leaked tokens. It falls under D4 if the posture changes. |
| No rate limit | **Deliberate**. The endpoint isn't an oracle and the token space can't be guessed. |

## RFC 8414 / RFC 9728: metadata

| Requirement | Status |
|---|---|
| Issuer, endpoints, grant types, PKCE methods and scopes advertised | **Conformant** |
| `revocation_endpoint_auth_methods_supported` matches behaviour (`["none"]`; an omitted value would mean `client_secret_basic`) | **Fixed** #2296 `96fc38053` |
| `response_modes_supported: ["query"]` (an omitted value implies fragment, which is unsupported) | **Fixed** #2296 `96fc38053`. Unknown `response_mode` is ignored, per RFC 6749 §3.1, not rejected. |
| `token_endpoint_auth_methods_supported` matches behaviour | **Conformant**. Changes with D3. |
| RFC 9728 protected-resource metadata | **Conformant** (#2296). It has one app-wide resource; MCP resources come in Phase B. |

## RFC 9207: issuer in the authorization response

| Requirement | Status |
|---|---|
| `iss` on success and error redirects, equal to the metadata issuer; `authorization_response_iss_parameter_supported: true` (mix-up defense, RFC 9700 §4.4) | **Fixed** #2296 `83e9118e7`. A single `Oauth::BaseController#oauth_issuer` feeds both the redirect and the metadata. |

## RFC 9700: open redirector

| Requirement | Status |
|---|---|
| Never auto-redirect errors to an untrusted URI (§4.11.2). Self-registered https hosts get the local error page for pre-consent errors; operator clients and loopback still redirect; deny after consent still redirects | **Fixed** #3080 `53cbb7f83` "Render pre-consent errors here for self-registered https clients", `c83b78752` (tests for every pre-consent error) |

## RFC 7591: dynamic client registration

| Requirement | Status |
|---|---|
| Loopback and https redirect URIs; fragments, plain-http public hosts and custom schemes rejected | **Conformant** (#2296, #3080) |
| Errors answer `invalid_client_metadata` or `invalid_redirect_uri`, never 500 (§3.2.2). An over-long or non-String `client_name` had raised a 500 on both databases | **Fixed** #2296 `96fc38053` |
| Open, unauthenticated registration of any https host (no initial access token, no host vetting) | **Deliberate** (#3080, hosted plan): Cursor and other generic MCP clients need it. bc3 vets hosts; Fizzy will cover the recognized-host tier with CIMD (Phase C′). Impersonating names on consent go to the consent design pass (D5). |
| Abandoned registrations are reclaimed (§5 abuse mitigation) | **Fixed** #3159 `d26a9ac74`, `fa904e5e3`. A daily sweep removes self-registered clients with no grant activity for 30 days, matching bc3's retention. It row-locks and shares that lock with issuance, so it can't race a code exchange. A refresh whose client row is gone gets a 400, not a 500. Groundwork in #2296 `54eb952ba` fixed the `access_tokens` association and a schema-only foreign key that migrated databases never had. |
| RFC 7592 management endpoint, initial access token, global registration cap | **Deliberate**: not built. RFC 7592 is optional. A global cap would turn one actor's abuse into an outage for everyone. |

## RFC 6750 / RFC 9110: resource-server challenge

| Requirement | Status |
|---|---|
| Challenges use the `Bearer` scheme (§3). Rails' default was `Token realm=` | **Fixed** #3158 `be293017c` "Answer API authentication failures with a Bearer challenge" |
| A presented but invalid or expired token gets 401 `error="invalid_token"` (§3.1); clients refresh on this hourly since #3081 | **Fixed** #3158 `be293017c` |
| A valid read token on a write gets 403 `error="insufficient_scope", scope="write"`, so clients stop refreshing in a loop | **Fixed** #3158 `be293017c` |
| A JSON request with no credentials gets 401 plus a challenge instead of a 302 to sign-in (§3) | **Fixed** #3158, except for requests carrying a session cookie or `X-Requested-With`, which keep the 302 so in-app autosave and uploads don't break. **Open decision**: D6. |
| The scheme is matched case-insensitively (RFC 9110 §11.1) | **Fixed** #3158 `be293017c` |
| `resource_metadata` in the challenge (RFC 9728 §5.1), omitted while dark | **Fixed** #3158 `be293017c` |
| A Bearer header on an HTML request: 401, not the SHOULD-level 400 for `invalid_request` | **Deliberate** (#3158 summary); preserves the existing refusal. |

## Parity with bc3 not yet built

| Capability | Status |
|---|---|
| RFC 8707 resource indicators and audience stamping; the API refuses audienced tokens | **Planned**: Phase B. The `resource` parameter is ignored today, which RFC 6749 §3.1 permits. Must ship before any MCP-audienced token is issued. |
| One account per connection (account-bound grants, account picker at consent) | **Planned**: Phase B, Decision 4. OAuth tokens are identity-wide today, like personal access tokens. |
| RFC 8693 token exchange for the MCP server | **Planned**: Phase C, on top of B. Copy bc3's error table, and don't copy bc3's `client_secret_basic` gap. |
| Per-client token rate limit after confidential authentication | **Planned**: Phase C |
| DPoP-bound delegated tokens, replay store (port the bc3#12535 fix), `htu` behind kamal-proxy | **Planned**: Phase C′. #3158 already parses the scheme, so the DPoP branch can reuse it. The binding check must be keyed on the token row, not on the header. |
| CIMD (URL client ids, recognized hosts, SSRF-guarded via Surfguard) | **Planned**: Phase C′, after DPoP |
| Device authorization grant (RFC 8628) | **N/A for now**: there's no consumer. fizzy-cli uses personal access tokens, and a CLI can use a loopback redirect with PKCE. Revisit if fizzy-cli moves to OAuth login. |
| Token introspection (RFC 7662) | **N/A**: exchange is the chosen model. |

## Decisions

These need Jeremy. Everything else above is either conformant, fixed in the
train, or planned.

1. **D1: refresh-token replay detection (MUST for public clients).** Reverse
   #3081's "deliberately not done"? Proposed change: keep one
   `previous_refresh_token` digest on the grant row and stamp it inside the
   rotation compare-and-swap. A replay outside a 30–60s grace window destroys the
   grant; inside the window it is a plain `invalid_grant`, which covers a lost
   response or a concurrent loser. Every case answers `invalid_grant`. This goes
   in #3081, then #3082 and the PRs above it are rebased. This is bc3 parity.
2. **D2: refresh idle expiry (SHOULD).** Adopt a sliding 90-day idle window, keyed
   on `expires_at`, with a daily purge of idle grants? Active connectors are
   unaffected. This goes in #3081. If declined, record the reason in #3081's body.
3. **D3: `client_secret_basic` (MUST).** Add Basic alongside post: any
   confidential client may present either, a failed Basic attempt gets 401 +
   `WWW-Authenticate: Basic`, sending both methods is `invalid_request`, and DCR
   and metadata advertise it. The change is additive at #3082. Align with bc3's
   resolution of the same gap.
4. **D4: revocation client authentication (RFC 7009 §2.1 MUST).** The open
   thread on #3082. Today anyone holding a token can revoke it. The narrow case
   that argues for changing this: a stolen refresh token belonging to a
   confidential client can't be used without its secret, but it can still be
   revoked, cutting off the user. Options: (a) keep the posture and correct the
   #3082 body's rationale; (b) authenticate a token's own confidential client
   and bind the token to it, keeping holder-can-revoke for public clients and
   personal access tokens. bc3 does (b). Under (b), metadata becomes
   `["none", "client_secret_post"]`.
5. **D5: consent for self-registered clients.** For the consent design pass:
   lead with the redirect host rather than the self-asserted `client_name`, and
   refuse impersonating names (Fizzy, Basecamp, HEY, Claude, ChatGPT) for
   self-registered clients.
6. **D6: rule for the no-credentials 401 (#3158).** A JSON request with no
   session cookie and no `X-Requested-With` gets 401 + Bearer; anything else
   keeps the 302, so in-app autosave isn't sent to the challenge URL by
   `@rails/request.js`. An API client that sends `X-Requested-With` without
   credentials still gets a 302. Accept this rule, or narrow it?

Also outside this train: the Security check is red on new runs because of
rubyzip 3.3.0 (CVE-2026-85396). main already has 3.7.0, so the check clears once
the train is brought up to date with main. That is a separate step, and isn't
done here.
