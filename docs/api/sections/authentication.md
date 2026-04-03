# Authentication

There are two ways to authenticate with the Fizzy API:

1. **Personal access tokens** - Long-lived tokens for scripts and integrations
2. **Magic link authentication** - Session-based authentication for native apps

## Personal Access Tokens

To use the API you'll need an access token. To get one, go to your profile, then,
in the API section, click on "Personal access tokens" and then click on
"Generate new access token".

Give it a description and pick what kind of permission you want the access token to have:
- `Read`: allows reading data from your account
- `Read + Write`: allows reading and writing data to your account on your behalf

Then click on "Generate access token".

<details>
  <summary>Access token generation guide with screenshots</summary>

  | Step | Description | Screenshot |
  |:----:|-------------|:----------:|
  | 1 | Go to your profile | <img width="400" alt="Profile page with API section" src="https://github.com/user-attachments/assets/49e7e12b-2952-4220-84fd-cef99b13bc04" /> |
  | 2 | In the API section click on "Personal access token" | <img width="400" alt="Personal access tokens page" src="https://github.com/user-attachments/assets/2f026ea0-416f-4fbe-a097-61313f24f180" /> |
  | 3 | Click on "Generate a new access token" | <img width="400" alt="Generate new access token dialog" src="https://github.com/user-attachments/assets/d766f047-8628-416d-8e21-b89522f6c0d9" /> |
  | 4 | Give it a description and assign it a permission | <img width="400" alt="Access token created" src="https://github.com/user-attachments/assets/49b8e350-d152-4946-8aad-e13260b983fd" /> |
</details>

> [!IMPORTANT]
> __An access token is like a password, keep it secret and do not share it with anyone.__
> Any person or application that has your access token can perform actions on your behalf.

To authenticate a request using your access token, include it in the `Authorization` header:

```bash
curl -H "Authorization: Bearer put-your-access-token-here" -H "Accept: application/json" https://app.fizzy.do/my/identity
```

## Magic Link Authentication

For native apps, you can authenticate users via magic links. This is a two-step process:

### 1. Request a magic link

Send the user's email address to request a magic link be sent to them:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"email_address": "user@example.com"}' \
  https://app.fizzy.do/session
```

__Response:__

```
HTTP/1.1 201 Created
Set-Cookie: pending_authentication_token=...; HttpOnly; SameSite=Lax
```

```json
{
  "pending_authentication_token": "eyJfcmFpbHMi..."
}
```

The response includes a `pending_authentication_token` both in the JSON body and as a cookie.
Native apps should store this token and include it as a cookie when submitting the magic link code.

__Error responses:__

| Status Code | Description |
|--------|-------------|
| `422 Unprocessable entity` | Invalid email address, if sign ups are enabled and the value isn't a valid email address |
| `429 Too Many Requests` | Rate limit exceeded |

### 2. Submit the magic link code

Once the user receives the magic link email, they'll have a 6-character code. Submit it to complete authentication:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Cookie: pending_authentication_token=eyJfcmFpbHMi..." \
  -d '{"code": "ABC123"}' \
  https://app.fizzy.do/session/magic_link
```

__Response:__

```json
{
  "session_token": "eyJfcmFpbHMi..."
}
```

The `session_token` can be used to authenticate subsequent requests by including it as a cookie:

```bash
curl -H "Cookie: session_token=eyJfcmFpbHMi..." \
  -H "Accept: application/json" \
  https://app.fizzy.do/my/identity
```

__Error responses:__

| Status Code | Description |
|--------|-------------|
| `401 Unauthorized` | Invalid `pending_authentication_token` or `code` |
| `429 Too Many Requests` | Rate limit exceeded |


### Delete server-side session (_log out_)

To log out and destroy the server-side session:

```bash
curl -X DELETE \
  -H "Accept: application/json" \
  -H "Cookie: session_token=eyJfcmFpbHMi..." \
  https://app.fizzy.do/session
```

__Response:__

Returns `204 No Content` on success.

### Create an access token via the API

You can programmatically create a personal access token using either a session cookie or an existing Bearer token:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Cookie: session_token=eyJfcmFpbHMi..." \
  -d '{"access_token": {"description": "Fizzy CLI", "permission": "write"}}' \
  https://app.fizzy.do/1234567/my/access_tokens
```

Or with a Bearer token (must have `write` permission):

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer put-your-access-token-here" \
  -d '{"access_token": {"description": "Fizzy CLI", "permission": "write"}}' \
  https://app.fizzy.do/1234567/my/access_tokens
```

The `permission` field accepts `read` or `write`.

__Response:__

```
HTTP/1.1 201 Created
```

```json
{
  "token": "4f9Q6d2wXr8Kp1Ls0Vz3BnTa",
  "description": "Fizzy CLI",
  "permission": "write"
}
```

Store the `token` value securely — it won't be retrievable again. Use it as a Bearer token for subsequent API requests.
