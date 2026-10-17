# OAuth: where Fizzy stands against our OAuth rubric

The bar is described in bc3's [`doc/oauth/rubric.md`](https://github.com/basecamp/bc3/blob/master/doc/oauth/rubric.md), drafted in basecamp/bc3#13882: one design and conformance rubric for OAuth across our apps' authorization servers. Each app builds to it natively, and the conformance suite (`basecamp-mcp-server` `cmd/mcp-authserver-verify`) shows where it stands. This file records where Fizzy stands, by check id.

Fizzy is becoming a full OAuth authorization server. Legacy personal access tokens become a degenerate case: one-off OAuth access tokens (LG-1). Fizzy is an existing app, and its shipped clients' PATs and session cookies keep working (#3191), so it migrates at their pace. A ✗ here is migration debt, not a failure.

Status is `main` as of 2026-10-15:
- ✓ met
- ◐ partly met, or in an open PR
- ✗ not met
- ? not yet assessed
- — doesn't apply

Main has no OAuth yet. The train is #2296 → #3080 → #3081 → #3082 → #3160 → #3161 → #3159 → #3163 → #3169 → #3192, with #3158 beside #3160, and it is integrated for beta on `oauth-integration-2026-10-15`. Fizzy's own RFC ledger is `docs/oauth/spec_conformance.md` on #3159.

## Status

| Id | Status | Note |
|---|---|---|
| SE-1, SE-2 | ? | Sessions and magic links. Whether sign-out-everywhere ends native app sessions has not been assessed. |
| SE-3 | ◐ | OAuth grants are separate from sessions (#2296). |
| SE-4 / SE-4t | — | No passwords (magic links). |
| GP-1, GP-2, GP-6 | ◐ | #2296: code only, S256 only, `iss`. |
| GP-7 | ◐ | #2296: `state` is optional; when sent it's one string of at most 2048 characters, echoed exactly (`Oauth::AuthorizationsController#validate_state`). |
| GP-3 | ◐ | #2296. |
| GP-4 | ◐ | Stateless codes with a jti; a revoke inside the 60s doesn't stop redemption (no tombstone). |
| GP-5 | ◐ | In the train, a replayed code destroys the grant its first redemption made (`Identity::AccessToken.redeem`), after client, redirect URI and PKCE are checked. |
| GP-8 | — | Declined: no consumer. |
| GP-9 | ✗ | PAR. |
| GP-10 | ✗ | Token exchange (Phase C). |
| NA-* | — | No first-party native OAuth clients yet. Any future native client starts at the bar. |
| RT-1 | ◐ | #3081 |
| RT-2 | ◐ | #3160 |
| RT-3 | ◐ | #3160 / #3161 |
| RT-4 | ◐ | #3161 |
| RT-5 | ◐ | #3081 |
| CR-1 | ◐ | DCR only, no registry or CIMD. |
| CR-2 | ◐ | #3082 |
| CR-3 | ◐ | #3080, #3159. No global registration cap. |
| CR-4 | ✗ | CIMD (Phase C′). |
| CR-5, CR-6 | ◐ | #2296, #3080 |
| DS-1, DS-2 | ◐ | #2296 |
| DS-3 | ◐ | #3158 (decision D6 open). |
| DS-4 | ✗ | |
| TK-1 | ◐ | #3163: `fizzy_pat_`, `fizzy_at_`, `fizzy_rt_`, `fizzy_cs_`, each with 44 base58 characters (257 bits). Codes are stateless and unprefixed (GP-4). Not registered with GitHub secret scanning. |
| TK-2 | ◐ | #3192 is step 1 of 3 (read by digest, plaintext fallback). Storing plaintext was an oversight; the conformance ledger's "Deliberate" entry is withdrawn. Steps 2 and 3 remove the fallback and the plaintext columns. The token-column index comes with step 1. |
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
| LG-1 | ◐ | In the train, PATs and OAuth tokens share `Identity::AccessToken` (`personal` and `oauth` scopes, by `oauth_client_id`). What's left: PATs as grant records, listed with connected apps. |
| LG-2 | ✗ | Migrate them in place, keeping reach, non-expiry and the token string. Pinned by #3191. |
| SC-1 | ◐ | Per-IP limits only: token 20/min, revocation 20/min, registration 10/min. |
| SC-2, SC-3 | ✗ | Per-client limits after authentication, and platform pacing (Phase C). |
| SC-4 | ✗ | |
| SC-5 | ◐ | #3082: every OAuth response carries `Cache-Control: no-store` and `Referrer-Policy: no-referrer` (`Oauth::BaseController`). Consent has CSRF protection and a `form-action` limited to the validated redirect. |
| SC-6 | ◐ | #2296 filters `code`, `code_verifier`, `device_code`, `client_assertion` and `dpop` beside the existing `token` and `secret` matches, the logged redirect included. SQL and slow-query logs are separate work. |
| SC-7 | ◐ | Switches are off by default (#2296). |
| AU-1..3, OB-1..2 | ✗ | No events or metrics in the OAuth code. |
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
