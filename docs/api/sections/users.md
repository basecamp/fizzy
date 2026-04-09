# Users

Users represent people who have access to an account.

## `GET /:account_slug/users`

Returns a list of active users in the account.

__Response:__

```json
[
  {
    "id": "03f5v9zjw7pz8717a4no1h8a7",
    "name": "David Heinemeier Hansson",
    "role": "owner",
    "active": true,
    "email_address": "david@example.com",
    "created_at": "2025-12-05T19:36:35.401Z",
    "url": "http://app.fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
  },
  {
    "id": "03f5v9zjysoy0fqs9yg0ei3hq",
    "name": "Jason Fried",
    "role": "member",
    "active": true,
    "email_address": "jason@example.com",
    "created_at": "2025-12-05T19:36:35.419Z",
    "url": "http://app.fizzy.localhost:3006/897362094/users/03f5v9zjysoy0fqs9yg0ei3hq"
  },
  {
    "id": "03f5v9zk1dtqduod5bkhv3k8m",
    "name": "Jason Zimdars",
    "role": "member",
    "active": true,
    "email_address": "jz@example.com",
    "created_at": "2025-12-05T19:36:35.435Z",
    "url": "http://app.fizzy.localhost:3006/897362094/users/03f5v9zk1dtqduod5bkhv3k8m"
  },
  {
    "id": "03f5v9zk3nw9ja92e7s4h2wbe",
    "name": "Kevin Mcconnell",
    "role": "member",
    "active": true,
    "email_address": "kevin@example.com",
    "created_at": "2025-12-05T19:36:35.451Z",
    "url": "http://app.fizzy.localhost:3006/897362094/users/03f5v9zk3nw9ja92e7s4h2wbe"
  }
]
```

## `GET /:account_slug/users/:user_id`

Returns the specified user.

__Response:__

```json
{
  "id": "03f5v9zjw7pz8717a4no1h8a7",
  "name": "David Heinemeier Hansson",
  "role": "owner",
  "active": true,
  "email_address": "david@example.com",
  "created_at": "2025-12-05T19:36:35.401Z",
  "url": "http://app.fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
}
```

## `PUT /:account_slug/users/:user_id`

Updates a user. You can only update users you have permission to change.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | No | The user's display name |
| `avatar` | file | No | The user's avatar image |

__Request:__

```json
{
  "user": {
    "name": "David H. Hansson"
  }
}
```

__Response:__

Returns `204 No Content` on success.

## `DELETE /:account_slug/users/:user_id/avatar`

Removes the user's avatar image. You can only remove avatars for users you have permission to change.

__Response:__

Returns `204 No Content` on success.

## `POST /:account_slug/users/:user_id/email_addresses`

Initiates an email address change for the user. A confirmation email is sent to the new address with a token link. You can only change your own email address.

This is a two-step process, similar to magic link authentication:

1. Request the change (this endpoint) — a confirmation email is sent to the new address
2. Confirm the change (`POST .../confirmation`) — the token from the email is submitted to complete the change

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `email_address` | string | Yes | The new email address |

__Response:__

Returns `201 Created` on success. The user must check the new email address for a confirmation link.

__Error responses:__

| Status Code | Description |
|--------|-------------|
| `400 Bad Request` | Missing `email_address` parameter |
| `404 Not Found` | User is not your own |
| `422 Unprocessable Entity` | Invalid email format, same as current email, or already belongs to a user in the same account |
| `429 Too Many Requests` | Rate limit exceeded (5 per hour) |

## `POST /:account_slug/users/:user_id/email_addresses/:token/confirmation`

Confirms an email address change using the token from the confirmation email. This endpoint does not require authentication — the token itself serves as proof of access to the new email.

The token is the full value from the confirmation URL sent in the email. It expires after 30 minutes.

__Response:__

Returns `204 No Content` on success. The user's email address has been changed.

__Error responses:__

| Status Code | Description |
|--------|-------------|
| `422 Unprocessable Entity` | Token is invalid or has expired |
| `429 Too Many Requests` | Rate limit exceeded (5 per hour) |

## `DELETE /:account_slug/users/:user_id`

Deactivates a user. You can only deactivate users you have permission to change.

__Response:__

Returns `204 No Content` on success.
