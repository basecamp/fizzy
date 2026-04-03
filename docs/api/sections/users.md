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
    "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
  },
  {
    "id": "03f5v9zjysoy0fqs9yg0ei3hq",
    "name": "Jason Fried",
    "role": "member",
    "active": true,
    "email_address": "jason@example.com",
    "created_at": "2025-12-05T19:36:35.419Z",
    "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjysoy0fqs9yg0ei3hq"
  },
  {
    "id": "03f5v9zk1dtqduod5bkhv3k8m",
    "name": "Jason Zimdars",
    "role": "member",
    "active": true,
    "email_address": "jz@example.com",
    "created_at": "2025-12-05T19:36:35.435Z",
    "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zk1dtqduod5bkhv3k8m"
  },
  {
    "id": "03f5v9zk3nw9ja92e7s4h2wbe",
    "name": "Kevin Mcconnell",
    "role": "member",
    "active": true,
    "email_address": "kevin@example.com",
    "created_at": "2025-12-05T19:36:35.451Z",
    "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zk3nw9ja92e7s4h2wbe"
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
  "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
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

## `DELETE /:account_slug/users/:user_id`

Deactivates a user. You can only deactivate users you have permission to change.

__Response:__

Returns `204 No Content` on success.
