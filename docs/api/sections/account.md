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
