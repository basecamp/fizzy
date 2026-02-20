# Forward Auth integration

Fizzy can authenticate requests using headers set by a Forward Auth gateway (e.g. [Stargate](https://github.com/soulteary/stargate)). When the gateway has already verified the user, it adds headers such as `X-Auth-Email` to the request. If the request is from a **trusted source**, Fizzy treats it as authenticated and sets the current user accordingly—no magic link or login page required.

## When to use it

- You put Traefik (or another reverse proxy) and Stargate in front of Fizzy.
- Stargate performs login/session/OTP checks and, on success, forwards the request to Fizzy with extra headers.
- You want a single sign-on flow at the edge so Fizzy does not implement its own login for those requests.

## Required headers from the gateway

The gateway must set at least:

| Header         | Required | Description |
|----------------|----------|-------------|
| `X-Auth-Email` | Yes      | Authenticated user's email (used to find or create Identity and User). |

Optional:

| Header        | Description |
|---------------|-------------|
| `X-Auth-User` | Gateway's user identifier; can be used as the Fizzy user's display name when auto-provisioning. |
| `X-Auth-Amr`  | Authentication method (e.g. `otp,dingtalk`); for logging/audit only. |

`X-Forwarded-For` and `X-Real-Ip` are not used for authentication but may be used by Fizzy for logging/audit (e.g. `request.remote_ip`).

## Trust and security

Fizzy only trusts Forward Auth headers when the request is considered **trusted**. Do not trust headers from the public internet, or anyone could impersonate users by sending `X-Auth-Email`.

You must configure at least one trust mechanism when Forward Auth is enabled. If both trusted IPs and the secret header are empty or unset, no request is trusted (this avoids accidentally trusting all IPs).

Configure trust using one or both of:

1. **Trusted IPs**  
   Only requests whose `request.remote_ip` is in the configured list (or CIDR) are trusted. Typically you list the IP(s) of your Traefik/Stargate instance(s) or your internal network (e.g. `127.0.0.1`, `10.0.0.0/8`). When Fizzy runs behind Docker and receives requests from Traefik on the same Docker network, the connection may come from a `172.16.0.0/12` address—include that range if you rely on IP trust.

2. **Secret header**  
   The gateway sets a custom header (e.g. `X-Forward-Auth-Verified`) to a shared secret. Fizzy checks that the header value matches the configured secret. Use a strong, random value and keep it secret.

If both are configured, the request must satisfy both (IP in list and secret header correct).

## Configuration (environment variables)

| Variable | Default | Description |
|----------|---------|-------------|
| `FORWARD_AUTH_ENABLED` | (off) | Set to `true` or `1` to enable Forward Auth. |
| `FORWARD_AUTH_TRUSTED_IPS` | (empty) | Comma-separated IPs or CIDRs (e.g. `127.0.0.1,10.0.0.0/8`). If empty, trust is based only on the secret header (if set). |
| `FORWARD_AUTH_SECRET_HEADER` | (none) | Name of the header the gateway sets with the secret (e.g. `X-Forward-Auth-Verified`). |
| `FORWARD_AUTH_SECRET` | (none) | Expected value of that header. Use a long random string. |
| `FORWARD_AUTH_AUTO_PROVISION` | `false` | If `true`, Fizzy will create an Identity (by email) and/or a User (in the current account) when they do not exist. If `false`, the Identity and User must already exist. |
| `FORWARD_AUTH_DEFAULT_ROLE` | `member` | Role assigned when auto-provisioning a User (`owner`, `admin`, `member`, `system`). |
| `FORWARD_AUTH_CREATE_SESSION` | `true` | If `true`, on successful Forward Auth login Fizzy creates a normal session and sets the session cookie so ActionCable and later requests work without headers. If `false`, every request must carry the Forward Auth headers. |
| `FORWARD_AUTH_USE_EMAIL_LOCAL_PART_AND_LOCK_EMAIL` | `false` | If `true`, when authenticating via Forward Auth: the display name is set from the email local part (e.g. `suyang` from `suyang@staff.linkerhub.work`) when auto-provisioning, and the identity's email is locked so it cannot be changed in profile settings. |
| `FORWARD_AUTH_AUTO_CREATE_ACCOUNT` | `true` | When `true`, a Forward Auth user with no accounts gets a new account created automatically and is redirected there, so they never see "You don't have any Fizzy accounts." Set to `false` to require manual sign-up. |
| `FORWARD_AUTH_AUTO_CREATE_ACCOUNT_NAME` | `My Workspace` | Name of the account created when `FORWARD_AUTH_AUTO_CREATE_ACCOUNT` is used. |

## Example: Stargate in front of Fizzy

1. Configure Traefik to use Stargate as Forward Auth for the Fizzy backend.
2. Configure Stargate so that after successful auth it adds `X-Auth-Email` (and optionally `X-Auth-User`) to the request to Fargate.
3. Set Fizzy env vars, for example:

   ```bash
   FORWARD_AUTH_ENABLED=true
   FORWARD_AUTH_TRUSTED_IPS=127.0.0.1,10.0.0.0/8
   FORWARD_AUTH_AUTO_PROVISION=true
   FORWARD_AUTH_CREATE_SESSION=true
   ```

4. Ensure requests to Fizzy go through Traefik so the client IP seen by Fizzy is the proxy (and in your trusted range), and the headers are present.

## Behaviour summary

- **Authentication order**  
  For each request that requires authentication, Fizzy tries: (1) Forward Auth headers (if enabled and trusted), (2) session cookie, (3) Bearer token, (4) redirect to login. Forward Auth is tried first so that when the request comes through the gateway with headers, the gateway identity is used even if the browser has an old session.

- **Account**  
  The current account is still taken from the URL path (e.g. `/{account_id}/boards`). Forward Auth only identifies the user; access to a given account still depends on that user having a User record in that account (or auto-provisioning, if enabled). When a Forward Auth user with no accounts hits the session menu and `FORWARD_AUTH_AUTO_CREATE_ACCOUNT` is `true` (default), a new account is created for them and they are redirected there, so they do not see "You don't have any Fizzy accounts."

- **Session**  
  If `FORWARD_AUTH_CREATE_SESSION` is `true`, the first successful Forward Auth login creates a Fizzy session and sets the cookie. WebSockets (ActionCable) and subsequent page loads then use the cookie and do not need the Forward Auth headers.

- **Logging**  
  Successful Forward Auth logins are logged (e.g. identity id and email) for audit; secrets and tokens are not logged.

## Risks

- **Trust scope**  
  Do not use a broad range (e.g. `0.0.0.0/0`) or a weak/leaked secret. Restrict to the proxy’s IP(s) and use a strong secret.

- **Multi-tenancy**  
  Forward Auth only answers “who is this user?”. “Which accounts they can access?” is still determined by Fizzy (URL + User membership and Access). Keep gateway and Fizzy configuration in sync if you rely on auto-provisioning.
