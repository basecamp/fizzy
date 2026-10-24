# OAuth: where Fizzy stands against our OAuth rubric

The bar is described in bc3's [`doc/oauth/rubric.md`](https://github.com/basecamp/bc3/blob/master/doc/oauth/rubric.md), drafted in basecamp/bc3#13882: one design and conformance rubric for OAuth across our apps' authorization servers. Each app builds to it natively, and the conformance suite (`basecamp-mcp-server` `cmd/mcp-authserver-verify`) shows where it stands. This file records where Fizzy stands, by check id.

Fizzy is becoming a full OAuth authorization server. Legacy personal access tokens become a degenerate case: one-off OAuth access tokens (LG-1). Fizzy is an existing app, and its shipped clients' PATs and session cookies keep working (#3191), so it migrates at their pace. A ✗ here is migration debt, not a failure.

Status is `main` as of 2026-10-15:
- ✓ met
- ◐ partly met, or in an open PR
- ✗ not met
- ? not yet assessed
- — doesn't apply

Main has no OAuth yet. The train is #2296 → #3080 → #3081 → #3082 → #3158 → #3160 → #3161 → #3159 → #3163 → #3169 → #3192. `oauth-integration-2026-10-15` carries #2296 through #3169, #3158 and #3191 for the manual beta migrations; #3192 and its three digest migrations still have to be merged into it before they run on beta. Stacked on #3192: #3204 (AU-1, OB-1), #3205 (LG-1, LG-2), #3206 (GP-4, GP-5), and the D2 and D3 drafts #3202 and #3203 (TK-2), gated on production running D1 and then D2. Fizzy's own RFC ledger is `docs/oauth/spec_conformance.md` on #3159.

## Status

| Id | Status | Note |
|---|---|---|
| SE-1, SE-2 | ? | Sessions and magic links. Whether sign-out-everywhere ends native app sessions has not been assessed. |
| SE-3 | ◐ | OAuth grants are separate from sessions (#2296). |
| SE-4 / SE-4t | — | No passwords (magic links). |
| GP-1, GP-2, GP-6 | ◐ | #2296: code only, S256 only, `iss`. |
| GP-7 | ◐ | #2296: `state` is optional; when sent it's one string of at most 2048 characters, echoed exactly (`Oauth::AuthorizationsController#validate_state`). |
| GP-3 | ◐ | #2296. |
| GP-4 | ◐ | Stateless codes with a jti, single-use by a unique record of each redeemed jti, kept 25 hours (#3206). Not yet bound to `resource` (Phase B). |
| GP-5 | ◐ | A replayed code destroys the grant its first redemption made (`Identity::AccessToken.redeem`), after client, redirect URI and PKCE are checked; #3206 keeps the code on record, so it mints nothing after its grant is gone. |
| GP-8 | — | Declined: no consumer. |
| GP-9 | ✗ | PAR. |
| GP-10 | ✗ | Token exchange (Phase C). |
| NA-* | — | No first-party native OAuth clients yet. Any future native client starts at the bar. |
| RT-1 | ◐ | #3081 |
| RT-2 | ◐ | #3160 |
| RT-3 | ◐ | #3160 / #3161 |
| RT-4 | ◐ | #3161 |
| RT-5 | ◐ | #3081: narrows, never widens. **Deviation:** a grant is one row, so narrowing on refresh narrows the grant for good, where RFC 6749 §6 would have the new refresh token keep its predecessor's scope. That's strictly more restrictive than the rubric (which forbids only widening), and authorizing the app again restores a broader scope. No column added. |
| CR-1 | ◐ | DCR only, no registry or CIMD. |
| CR-2 | ◐ | #3082 |
| CR-3 | ◐ | #3080, #3159. No global registration cap. |
| CR-4 | ✗ | CIMD (Phase C′). |
| CR-5, CR-6 | ◐ | #2296, #3080 |
| DS-1, DS-2 | ◐ | #2296 |
| DS-3 | ◐ | #3158: an invalid or expired Bearer token gets 401 `invalid_token`; an OAuth grant without write gets 403 `insufficient_scope`. **Deviations for shipped clients** (the native apps and fizzy-cli, pinned by #3191): a JSON request with no credentials keeps its 302 to sign in, since nothing in it tells a shipped client from an OAuth one; and a read-only personal access token writing keeps its 401, now with an `insufficient_scope` challenge. Hosted OAuth clients discover through fizzy-mcp-server's 401 + `resource_metadata` and Fizzy's `/.well-known` metadata, so this costs them little. **Exit:** once the oldest supported native app and fizzy-cli handle a 401 challenge there. |
| DS-4 | ✗ | |
| TK-1 | ◐ | #3163: `fizzy_pat_`, `fizzy_at_`, `fizzy_rt_`, `fizzy_cs_`, each with 44 base58 characters (257 bits). Codes are stateless and unprefixed (GP-4). Not registered with GitHub secret scanning. |
| TK-2 | ◐ | #3192 is step 1 of 3 (read by digest, plaintext fallback). Storing plaintext was an oversight; the conformance ledger's "Deliberate" entry is withdrawn. Steps 2 and 3 (#3202, #3203, drafts) remove the fallback and the plaintext column. The token-column index comes with step 1. |
| TK-3 | ✗ | Pepper keyring. |
| TK-4 | ◐ | #3081 |
| TK-5 | ◐ | `read`/`write` only. |
| TK-6 | ✗ | Audience and account binding (Phase B). Required before any MCP-audienced token. |
| TK-7 | ✗ | DPoP (Phase C′). |
| TK-8 | ◐ | |
| CX-1 | ◐ | Consent design for self-registered clients (decision D5) is open. |
| CX-2, CX-3 | ◐ | #2296 |
| CX-4 | ◐ | #3169 |
| CX-5, DX-1..2 | ✗ | |
| LG-1 | ◐ | #3205 issues PATs from a first-party `fizzy-personal-access` client in the same digest-stored table. They stay on `/my/access_tokens`, not in Connected Apps (LG-1 allows either), and keep the `fizzy_pat_` prefix for secret scanning (TK-1). |
| LG-2 | ◐ | #3205 backfills existing PATs onto that client in place, keeping reach, non-expiry and the token string. Pinned by #3191. |
| SC-1 | ◐ | Per-IP limits only: token 20/min, revocation 20/min, registration 10/min. |
| SC-2, SC-3 | ✗ | Per-client limits after authentication, and platform pacing (Phase C). |
| SC-4 | ✗ | |
| SC-5 | ◐ | #3082: every OAuth response carries `Cache-Control: no-store` and `Referrer-Policy: no-referrer` (`Oauth::BaseController`). Consent has CSRF protection and a `form-action` limited to the validated redirect. |
| SC-6 | ◐ | #2296 filters `code`, `code_verifier`, `device_code`, `client_assertion` and `dpop` beside the existing `token` and `secret` matches, the logged redirect included. SQL and slow-query logs are separate work. |
| SC-7 | ◐ | Switches are off by default (#2296). |
| AU-1, OB-1 | ◐ | #3204: lifecycle events through `Rails.event`, logged as structured lines in SaaS, and a Yabeda `oauth` group under bc3's names. |
| AU-2, AU-3, OB-2 | ✗ | |
| OP-1 | ◐ | #2296: `OAUTH_ACCEPTANCE_ENABLED`, `OAUTH_ISSUANCE_ENABLED`, `OAUTH_PILOT_CLIENT_IDS`. |
| OP-2 | ✗ | |
| OP-3 | ◐ | #3159, #3161 |
| OP-4, OP-5 | ✗ | |
| OP-6 | ◐ | This file, plus #3159's ledger. |

The grant-surface rule is an opt-in per controller (`disallow_oauth_grants`). It should become deny-by-default, so that a new credential surface can't leak an OAuth grant's reach.

## Order of work

1. Land the train in order, through the beta integration branch, with migrations run by hand on beta. Put the AU-1 and OB-1 instrumentation at its base.
2. Finish #3192's three steps (TK-2), then TK-3.
3. LG-1 and LG-2: migrate PATs in place.
4. Phase B (audience and account binding), Phase C (token exchange, per-client limits and pacing), Phase C′ (DPoP, CIMD).
5. CX-5, DX-1, OB-2, OP-2.
