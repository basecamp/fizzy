# Account

## `GET /account/settings`

Returns the current account.

__Response:__

```json
{
  "id": "03f5v9zjvypwh0t0e2rfh0h7k",
  "name": "37signals",
  "cards_count": 5,
  "created_at": "2025-12-05T19:36:35.401Z",
  "auto_postpone_period_in_days": 30
}
```

The `auto_postpone_period_in_days` is the account-level default in days (e.g. `30`). Cards are automatically moved to "Not Now" after this period of inactivity. Each board can override this with its own value.

## `GET /account/join_code`

Returns the account's join code for inviting new users. The join code URL can be shared with people to let them join the account.

__Response:__

```json
{
  "code": "abc123",
  "usage_count": 3,
  "usage_limit": 10,
  "url": "http://app.fizzy.localhost:3006/897362094/join/abc123",
  "active": true
}
```

A join code is `active` when `usage_count` is less than `usage_limit`.

## `PUT /account/join_code`

Updates the join code's usage limit. Requires admin role.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `usage_limit` | integer | Yes | Maximum number of times the join code can be used |

__Request:__

```json
{
  "account_join_code": {
    "usage_limit": 10
  }
}
```

__Response:__

Returns `204 No Content` on success.

## `DELETE /account/join_code`

Resets the join code, generating a new one and invalidating the old code. Requires admin role.

__Response:__

Returns `204 No Content` on success.

## `PUT /account/entropy`

Updates the account-level default auto close period. Requires admin role.

__Request:__

```json
{
  "entropy": {
    "auto_postpone_period_in_days": 30
  }
}
```

__Response:__

Returns the account object:

```json
{
  "id": "03f5v9zjvypwh0t0e2rfh0h7k",
  "name": "37signals",
  "cards_count": 5,
  "created_at": "2025-12-05T19:36:35.401Z",
  "auto_postpone_period_in_days": 30
}
```

## `PUT /:account_slug/boards/:board_id/entropy`

Updates the auto close period for a specific board. Requires board admin permission.

__Request:__

```json
{
  "board": {
    "auto_postpone_period_in_days": 90
  }
}
```

__Response:__

Returns the board object.
