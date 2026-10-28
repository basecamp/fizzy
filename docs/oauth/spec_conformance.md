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
| [#3192](https://github.com/basecamp/fizzy/pull/3192) | `oauth-token-digests` | Tokens and client secrets stored as digests, step 1 of 3 (on #3169) |
| [#3204](https://github.com/basecamp/fizzy/pull/3204) | `oauth-audit-metrics` | OAuth Standard AU-1 audit events and OB-1 metrics (on #3192) |

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
| Issuance can be paused (`OAUTH_ISSUANCE_ENABLED=false`) while existing tokens are still honored; minting and refresh answer 503 | **Fixed** #2296 `1183b2bee`; refresh covered in #3081 `0568c1392` |
| Pilot client ids are exempt by exact `client_id`; registration can't be used to claim a pilot id | **Fixed** #2296 `1183b2bee`, `9a9d3ce7a` "Keep registration dark when a request names a pilot client" |
| Revocation, Connected Apps and consent denial are never gated, so people can always shed access | **Conformant** (by design in `Oauth::Availability`) |
| Unset means dark, which differs from bc3's dev default; dark answers 404 where bc3 answers 503; protected-resource metadata is also 404 while dark | **Deliberate**. Fizzy has no other AS to name, and OSS installs that never mention OAuth must look like they have none. |

## RFC 6749 / OAuth 2.1: authorization endpoint

| Requirement | Status |
|---|---|
| `response_type=code` only | **Conformant** |
| PKCE required, `S256` only (OAuth 2.1 §4.1.1, RFC 7636) | **Conformant** |
| `code_verifier` is 43–128 unreserved characters (RFC 7636 §4.1); a malformed one fails like a wrong one | **Fixed** #2296 `694eb8d7b` "Refuse a PKCE verifier outside 43 to 128 unreserved characters". Matches bc3's `Oauth::Pkce::VERIFIER_PATTERN` |
| Exact `redirect_uri` match against the registered list; never redirect to an unregistered URI (§3.1.2, §4.1.2.1) | **Conformant** |
| Loopback redirects: only the port may vary, host and query must match exactly, http only (RFC 8252 §7.3) | **Fixed** #2296 `51155c5e3` "…vary only the loopback port" (exact host and query; restores a fix a resolved Copilot thread had recorded as done but that was lost), `771ed906d` "Vary the port only for http loopback redirects"; #3080 `3a52a06ac` (no port variance onto a fragment), `6685905d3` |
| `state` is optional; when sent it's a single string of at most 2048 characters, echoed back exactly | **Fixed** #2296 "Accept an authorization request without state, and bound one that has it". Was **Deliberate** (required). PKCE is the CSRF defence (OAuth 2.1 §7.5.1), and the rubric's GP-7 makes `state` optional. |
| Consent is CSRF-protected (§10.12) | **Conformant**. The app-wide Origin check (`forgery_protection_origin_check`) refuses same-site sibling origins as well as cross-site ones. A finding that it didn't was refuted. |
| Consent is always shown; `trusted` doesn't skip it | **Deliberate** (#2296 body) |
| CSP `form-action` lets the consent POST redirect to the validated redirect origin; Chrome had been stranding the flow | **Fixed** #2296 `d468283d7` "Let consent redirect past CSP…". Ported from bc3. Covered by a Chrome system test (`test/system/oauth_consent_test.rb`). |
| Canonical scope: "Read + Write" is `read write`; a `read write` request preselects it instead of silently downgrading to read | **Fixed** #2296 `d468283d7`; refresh reports the same string in #3081 `89e22441d` |

## RFC 6749 / OAuth 2.1: token endpoint

| Requirement | Status |
|---|---|
| Authorization codes are single-use; reuse is refused and the grant minted from that code is revoked (§4.1.2, §10.5; OAuth 2.1 §4.1.3) | **Fixed** #2296 `bd447dd7a` "Redeem each authorization code once…". A `jti` in the code plus a unique `identity_access_tokens.authorization_code_jti`. Reuse is checked only after PKCE, `redirect_uri` and `client_id` pass, so a leaked code without its verifier can't revoke the grant. Since #3206, each redemption also records the code's `jti` in `oauth_redeemed_authorization_codes`, in the same transaction as the grant, kept 25 hours (rubric GP-4, GP-5: at least 24 hours past expiry). So once a replay, the person or the app has revoked the grant, the code still mints nothing. |
| `client_id` required and matched to the code for public clients (§4.1.3) | **Fixed** #2296 `bd447dd7a`; one check shared by both grants in #3081 `f9a1885ff` |
| Missing or malformed parameters answer `invalid_request`, not `invalid_grant` or `unsupported_grant_type` (§5.2) | **Fixed** #2296 `bd447dd7a`, `ac884df5f` "Reject non-string token request parameters as malformed" (an array `refresh_token` had been accepted as an `IN` list; a hash had raised a 500); #3081 `f9a1885ff`, `2b2b7f2d6` |
| Exact `redirect_uri` equality with the code (§4.1.3) | **Conformant** |
| Responses, errors included, carry `Cache-Control: no-store` (§5.1) | **Fixed** #3082. Every authorization server response, discovery, consent, its redirects and revocation included, carries `Cache-Control: no-store` and `Referrer-Policy: no-referrer`, from a callback prepended ahead of every one that can halt ("Keep every authorization server response out of caches and Referers"; rubric SC-5) |
| Authorization codes, PKCE verifiers, client assertions, DPoP proofs, tokens and secrets are filtered from logs, the logged redirect to the client included | **Fixed** #2296 "Filter authorization codes, PKCE verifiers and DPoP proofs from logs" (rubric SC-6). SQL and slow-query logs are separate work. |
| A confidential client authenticates before anything about the grant is looked up, so a wrong secret reveals nothing about whether a code or refresh token is live | **Fixed** #3082 `a1c6aad55`, `d7795f51b` "Authenticate the named client before resolving the grant…" |
| A client that fails authentication gets `invalid_client`: 401 + `WWW-Authenticate: Basic` only for a failed Basic attempt, and 400 with no challenge for anything else (a body credential, a public client presenting a secret, a secret that authenticates no client, a body failure beside another scheme's header) (§5.2) | **Fixed** #3082 `b6b83296a` "Answer invalid_client with 400 unless Basic authentication failed". The same at the token endpoint and revocation. A bare 401 breaks RFC 9110 §15.5.2; a Basic challenge to a request that never tried Basic applies to nothing; oauth4webapi and openid-client surface a challenged 401 as `WWWAuthenticateChallengeError`, not `invalid_client`; and a Basic challenge on a form POST can pop a browser auth dialog. |
| Client credentials are read from the request body only, never the query string | **Conformant** (#3082 `38fd57bbc`) |
| Per-IP rate limit of 20/min on the token endpoint | **Conformant**. A per-client budget after confidential authentication is **Planned** (Phase C); the per-IP limit blocks hosted use. |

## RFC 6749 §2.3.1: client authentication

| Requirement | Status |
|---|---|
| `client_secret_post` | **Conformant** (#3082) |
| HTTP Basic (`client_secret_basic`) MUST be supported for clients issued a password; a failed Basic attempt gets 401 + `WWW-Authenticate` (§5.2) | **Fixed** #3082 `d65d0117c` "Accept client_secret_basic at the token endpoint". Either method authenticates any confidential client; both at once is `invalid_request`. DCR and metadata advertise it. bc3 closes the same gap in bc3#13678. |
| Client secrets are stored as digests, never in plaintext, and shown once, in the registration response | **Fixed** #3192 `oauth-token-digests` (was **Deliberate** plaintext, #3082 body). HMAC-SHA256 under a server pepper (`TokenDigester`), checked in constant time. **Deviation from bc3**, which stores client secrets with bcrypt (`has_secure_password :secret`): Fizzy only issues generated secrets, 257 bits of randomness (24-character secrets from before #3163, about 140), so a deliberately slow hash adds no guessing resistance that the entropy doesn't already give, and one keyed digest serves every credential. Without the pepper, a copy of the database gives nothing to test a guess against. |
| An OAuth grant can't reach a credential or consent surface: personal access tokens, Connected Apps, passkey registration, transfer links, email changes or OAuth consent. Anything it minted there would outlive disconnecting the app, and anything it removed would belong to another app | **Fixed** #2296 `196b9b0b3` "Keep OAuth grants out of every credential and consent surface" (`Authentication.disallow_oauth_grants`, declared on each such controller). Personal access tokens may still manage personal access tokens (fizzy-cli) |

## Token format

| Requirement | Status |
|---|---|
| Tokens are stored as HMAC-SHA256 digests under a server pepper, byte-compatible with bc3's `Oauth::TokenDigester`, and looked up by a unique index on the digest. Raw values are shown once: in the token response, the registration response, or the response that creates a personal access token | **Fixed** #3192 `oauth-token-digests`, step 1 of 3. OAuth access and refresh tokens and client secrets are digest-only, and a refresh retry within the grace window is answered from an encrypted copy of the successor pair that expires with the window. Personal access tokens are digested and, until step 3, still also kept in plaintext, because production code that reads only plaintext shares the database while beta runs this. One written without a digest is found by plaintext once and digested. Step 2 stops reading and writing plaintext; step 3 drops the column. |
| A personal access token is a one-off access token of a first-party client, `fizzy-personal-access` ("Personal Access Tokens"), in the same digest-stored table as every grant, as bc3's are of `bc-personal-access`. That client is provisioned by migration and on first use, is never self-registered (so the registration sweep skips it), and is listed for no grant type, so the authorization and token endpoints refuse it with `unauthorized_client`. A personal token is honored while OAuth is dark, never lapses, gets no expiry or refresh token, keeps the `fizzy_pat_` prefix and is revoked by possession, whichever form it takes. Existing tokens are backfilled in place: same string, reach and non-expiry, nothing re-issued | **Fixed** #3205 `oauth-pats-as-grants` (#3164 steps 1 to 3). Tokens with no client still read as personal, because production code that predates the client keeps writing them until it's deployed. Dropping that branch and making `oauth_client_id` NOT NULL wait until the backfill has run in production. Personal access tokens are still listed under personal access tokens, not Connected Apps, as in bc3 |
| Newly issued tokens carry a distinctive prefix naming their kind: `fizzy_pat_` (personal access token), `fizzy_at_` (OAuth access token), `fizzy_rt_` (OAuth refresh token). Tokens issued earlier have no prefix and still work | **Fixed** #3163. bc3 prefixes similarly (`bc_at_`, `bc_rt_`, and PATs as `bc_at_`). Client secrets carry `fizzy_cs_`, as bc3's carry `bc_cs_`. New tokens and secrets carry 44 base58 characters after the prefix, 257 bits, at least bc3's 32 bytes (rubric TK-1); earlier ones are 24 characters and keep working. Nobody has registered with GitHub's secret-scanning partner program, either here or in bc3. |

## Refresh tokens (RFC 6749 §6, OAuth 2.1 §4.3, RFC 9700 §4.14)

| Requirement | Status |
|---|---|
| Rotation on every refresh, atomic (compare-and-swap). A concurrent loser is a retry of the winning rotation: within the 60-second grace it gets the winner's pair, as a retry would (#3160); past it, it's a replay | **Conformant** (#3081, #3160) |
| Refresh may narrow scope, never widen it; blank or `null` scope is refused | **Conformant** (#3081). |
| A refresh token issued after narrowing keeps its predecessor's scope (RFC 6749 §6) | **Deliberate**: a grant is one row, so narrowing on refresh narrows the grant for good, and a later refresh can't ask for the wider scope again. Strictly more restrictive than the rubric (RT-5 forbids only widening); signing in to the app again restores a broader scope. No shipped client narrows on refresh. |
| `client_id` required and must match the grant | **Conformant** (#3081 `f9a1885ff`) |
| Public clients' refresh tokens MUST be sender-constrained, or rotated **with replay detection**: presenting a rotated-out token revokes the live one (OAuth 2.1 §4.3.1, RFC 9700 §4.14.2) | **Fixed** #3160 `cf4aa3192` "Revoke the grant when a rotated refresh token is replayed, with a retry grace". A replay revokes the grant. A retry within 60s, while the successor is still current, gets that successor, as in bc3. |
| Refresh tokens SHOULD expire after client inactivity (RFC 9700 §4.14.2) | **Fixed** #3161 `f97c959e0` "Lapse OAuth grants left idle for 90 days", `d6bfcc2b1`. This matches bc3's 90-day `refresh_token_ttl`. A grant that lapses restarts its client's 30-day sweep clock (#3159). |

## RFC 7009: revocation

| Requirement | Status |
|---|---|
| Revokes an access or refresh token, destroying the whole grant; always 200 for unknown tokens (§2.2) | **Conformant** |
| Missing token answers `invalid_request` JSON (§2.2.1) | **Fixed** #2296 `51155c5e3` |
| Confidential clients authenticate, and the token must have been issued to the requesting client (§2.1) | **Fixed** #3082 `e80b5b615` "Authenticate clients at revocation and revoke only their own tokens". A public client names its `client_id`. Unknown tokens, and tokens belonging to another client, get 200 and nothing is revoked. |
| A presented client secret that authenticates no client is refused with 400 `invalid_client` (401 + Basic if it came in a Basic header), whatever the token | **Deliberate**, and stricter than bc3: #3082 `c9375f186`, `29a5d118c`. A 200 would tell a client with a mistyped `client_id` that a live grant was dead. bc3 is being aligned to this. |
| A personal access token can be revoked here by whoever holds it. It's issued by no client that can authenticate (none, or the first-party `fizzy-personal-access` client, which has no secret), so holding it is the credential; client credentials sent alongside must still authenticate | **Fixed** #3082 `98619ab8f` "Revoke personal access tokens at the revocation endpoint again". Revocation works the same for every kind of token, which helps incident response such as revoking a leaked token. It held unchanged when personal access tokens became tokens of the `fizzy-personal-access` client (#3205). |
| Revocation is throttled like the token endpoint: 20 per minute per IP, then 429 `slow_down` (RFC 6749 §2.3.1, RFC 7009 §5) | **Fixed** #3082 `11e8e1ad8` "Throttle revocation like the token endpoint". Once revocation authenticated confidential clients, it became a place to guess secrets |

## RFC 8414 / RFC 9728: metadata

| Requirement | Status |
|---|---|
| Issuer, endpoints, grant types, PKCE methods and scopes advertised | **Conformant** |
| `revocation_endpoint_auth_methods_supported` matches behaviour (`["none", "client_secret_post", "client_secret_basic"]`; an omitted value would mean `client_secret_basic` alone) | **Fixed** #2296 `51155c5e3`; #3082 `e80b5b615` |
| `response_modes_supported: ["query"]` (an omitted value implies fragment, which is unsupported) | **Fixed** #2296 `51155c5e3`. Unknown `response_mode` is ignored, per RFC 6749 §3.1, not rejected. |
| `token_endpoint_auth_methods_supported` matches behaviour | **Conformant** (`none`, `client_secret_post`, `client_secret_basic`) |
| RFC 9728 protected-resource metadata | **Conformant** (#2296). It has one app-wide resource; MCP resources come in Phase B. |

## RFC 9207: issuer in the authorization response

| Requirement | Status |
|---|---|
| `iss` on success and error redirects, equal to the metadata issuer; `authorization_response_iss_parameter_supported: true` (mix-up defense, RFC 9700 §4.4) | **Fixed** #2296 `d468283d7`. A single `Oauth::BaseController#oauth_issuer` feeds the redirect, the metadata and the protected resource's `authorization_servers`. It's the origin with no trailing slash (`https://app.fizzy.do`), as bc3's `canonical_issuer_url`, since clients compare issuers as exact strings (RFC 8414 §3.3); #3192 dropped the slash `root_url` gave it. |

## RFC 9700: open redirector

| Requirement | Status |
|---|---|
| Never auto-redirect errors to an untrusted URI (§4.11.2). Self-registered https hosts get the local error page for pre-consent errors; operator clients and loopback still redirect; deny after consent still redirects | **Fixed** #3080 `35c8d0de9` "Render pre-consent errors here for self-registered https clients", `4809449a0` (tests for every pre-consent error) |

## RFC 7591: dynamic client registration

| Requirement | Status |
|---|---|
| Loopback and https redirect URIs; fragments, plain-http public hosts and custom schemes rejected | **Conformant** (#2296, #3080) |
| A self-registered redirect names its authority plainly: no userinfo, no percent-encoded host, a port from 1 to 65535. Consent names a non-default port, and loopback port variation keeps userinfo fixed | **Fixed** #3080 `91b975e6e` "Register only redirects whose authority is plain, and show their port on consent". One rule at registration, in place of canonicalizing wherever the URI is shown or compared |
| Errors answer `invalid_client_metadata` or `invalid_redirect_uri`, never 500 (§3.2.2). An over-long or non-String `client_name` had raised a 500 on both databases | **Fixed** #2296 `51155c5e3` |
| Open, unauthenticated registration of any https host (no initial access token, no host vetting) | **Deliberate** (#3080, hosted plan): Cursor and other generic MCP clients need it. bc3 vets hosts; Fizzy will cover the recognized-host tier with CIMD (Phase C′). Impersonating names on consent go to the consent design pass (D5). |
| Abandoned registrations are reclaimed (§5 abuse mitigation) | **Fixed** #3159 `de3de6185`, `c3a296cec`. A daily sweep removes self-registered clients with no grant activity for 30 days, matching bc3's retention. It row-locks and shares that lock with issuance, so it can't race a code exchange. Under the lock it rechecks the whole stale test, and consent touches the client, so a client isn't swept between consent and its code exchange (`3398ff00e`). A refresh whose client row is gone gets a 400, not a 500. Groundwork in #2296 `65e4d3e7c` fixed the `access_tokens` association and a schema-only foreign key that migrated databases never had. |
| RFC 7592 management endpoint, initial access token, global registration cap | **Deliberate**: not built. RFC 7592 is optional. A global cap would turn one actor's abuse into an outage for everyone. |

## RFC 6750 / RFC 9110: resource-server challenge

| Requirement | Status |
|---|---|
| Challenges use the `Bearer` scheme (§3). Rails' default was `Token realm=` | **Fixed** #3158 `cc7d07659` "Answer API authentication failures with a Bearer challenge" |
| A presented but invalid or expired token gets 401 `error="invalid_token"` (§3.1); clients refresh on this hourly since #3081 | **Fixed** #3158 `cc7d07659` |
| A valid read token on a write gets 403 `error="insufficient_scope", scope="write"`, so clients stop refreshing in a loop | **Fixed** #3158 for OAuth grants. A read-only personal access token keeps the 401 shipped clients have always had, with the same `insufficient_scope` challenge (**Deliberate**, pinned by #3191). |
| A JSON request with no credentials gets 401 plus a challenge instead of a 302 to sign-in (§3) | **Deliberate** (D6): it keeps the 302. Nothing in a request without credentials tells the native apps or fizzy-cli, which rely on the redirect (pinned by #3191), from an OAuth client. Hosted OAuth clients discover Fizzy's authorization server through fizzy-mcp-server's own 401 + `resource_metadata` and Fizzy's `/.well-known` metadata, not a credential-less call to Fizzy's API, so it costs them little. **Exit:** once the oldest supported native app and fizzy-cli handle a 401 challenge on an unauthenticated JSON request. |
| The scheme is matched case-insensitively (RFC 9110 §11.1) | **Fixed** #3158 `cc7d07659` |
| `resource_metadata` in the challenge (RFC 9728 §5.1), omitted while dark | **Fixed** #3158 `cc7d07659` |
| A Bearer header on an HTML request: 401, not the SHOULD-level 400 for `invalid_request` | **Deliberate** (#3158 summary); preserves the existing refusal. |

## Audit events and metrics (OAuth Standard AU-1, OB-1)

| Requirement | Status |
|---|---|
| AU-1: lifecycle events in the standard's vocabulary, with its fields, and never a token, secret or digest | **Fixed** #3204 `oauth-audit-metrics`. `Oauth::Audit` reports through `Rails.event`: `oauth.client.{registered,swept}`, `oauth.consent.{shown,approved,denied}`, `oauth.code.{issued,redeemed,replayed}`, `oauth.grant.{created,narrowed,revoked}`, `oauth.token.{issued,refreshed,grace_replay,reuse_detected}`, `oauth.pat.{created,revoked}`. Grants and PATs report their creation and ending from after-commit callbacks, so every way one ends reports, with a reason, cascades included. SaaS writes each event as its own structured log line (Loki), joined to the request line by `transaction.id`. No new personal data: identity and tenant ids are those the request log already records, and the IP address and user agent stay on the request line. Fizzy revokes whole grants, so `oauth.token.revoked` is `oauth.grant.revoked` with `presented: access\|refresh`. |
| OB-1: one Yabeda `oauth` group under bc3's names and labels | **Fixed** #3204 `oauth-audit-metrics`, SaaS only (`saas/lib/yabeda/oauth.rb`): `token_grants_total`, `token_errors_total`, `token_request_duration_seconds`, `authorization_grants_total`, `authorization_denials_total`, `revocations_total`, `family_revocations_total`, `replays_total{kind=grace\|reuse}`, `dcr_registrations_total`, `dcr_rejections_total`, `rate_limit_hits_total`, `cleanup_step_failures_total`. Core code reports events and notifications only, so OSS doesn't depend on Yabeda. No client id is a label, and the scrape already adds `app="fizzy"`. |
| AU-2, AU-3, OB-2 | **Planned**. AU-2 needs an admin disable action, which Fizzy doesn't have. OB-2 is the dashboard and alerts, kept as code. |

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
holds them, and a client secret that authenticates no client gets 400
`invalid_client` (401 + Basic only when it came in a Basic header).

5. **D5: consent for self-registered clients.** For the consent design pass:
   lead with the redirect host rather than the self-asserted `client_name`, and
   refuse impersonating names (Fizzy, Basecamp, HEY, Claude, ChatGPT) for
   self-registered clients.
6. **D6 (#3158), decided: shipped clients keep their answers.** A JSON
   request with no credentials keeps the 302 (DS-3 deviation, row above), and
   a read-only personal access token writing keeps its 401; only an OAuth
   grant gets the 403.

The train is rebased onto main, which carries rubyzip 3.7.0, so the Security
audit no longer flags rubyzip 3.3.0 (CVE-2026-85396).
