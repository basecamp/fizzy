# Identity

An Identity represents a person using Fizzy.

## `GET /my/identity`

Returns a list of accounts the identity has access to, including the user for each account.

__Response:__

```json
{
  "accounts": [
    {
      "id": "03f5v9zjskhcii2r45ih3u1rq",
      "name": "37signals",
      "slug": "/897362094",
      "created_at": "2025-12-05T19:36:35.377Z",
      "user": {
        "id": "03f5v9zjw7pz8717a4no1h8a7",
        "name": "David Heinemeier Hansson",
        "role": "owner",
        "active": true,
        "email_address": "david@example.com",
        "created_at": "2025-12-05T19:36:35.401Z",
        "url": "http://app.fizzy.localhost:3006/users/03f5v9zjw7pz8717a4no1h8a7"
      }
    },
    {
      "id": "03f5v9zpko7mmhjzwum3youpp",
      "name": "Honcho",
      "slug": "/686465299",
      "created_at": "2025-12-05T19:36:36.746Z",
      "user": {
        "id": "03f5v9zppzlksuj4mxba2nbzn",
        "name": "David Heinemeier Hansson",
        "role": "owner",
        "active": true,
        "email_address": "david@example.com",
        "created_at": "2025-12-05T19:36:36.783Z",
        "url": "http://app.fizzy.localhost:3006/users/03f5v9zppzlksuj4mxba2nbzn"
      }
    }
  ]
}
```

## `PATCH /my/timezone`

Updates the current user's timezone. This affects how times are displayed in notification emails.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `timezone_name` | string | Yes | IANA timezone identifier (e.g. `America/New_York`, `Europe/London`, `Asia/Tokyo`) |

__Request:__

```json
{
  "timezone_name": "America/New_York"
}
```

__Response:__

Returns `204 No Content` on success.
