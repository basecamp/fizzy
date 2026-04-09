# Boards

Boards are where you organize your work - they contain your cards.

## `GET /:account_slug/boards`

Returns a list of boards that you can access in the specified account.

__Response:__

```json
[
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohcm",
    "name": "Fizzy",
    "all_access": true,
    "created_at": "2025-12-05T19:36:35.534Z",
    "auto_postpone_period_in_days": 30,
    "url": "http://app.fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm",
    "creator": {
      "id": "03f5v9zjw7pz8717a4no1h8a7",
      "name": "David Heinemeier Hansson",
      "role": "owner",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://app.fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
    }
  }
]
```

## `GET /:account_slug/boards/:board_id`

Returns the specified board.

__Response:__

```json
{
  "id": "03f5v9zkft4hj9qq0lsn9ohcm",
  "name": "Fizzy",
  "all_access": false,
  "created_at": "2025-12-05T19:36:35.534Z",
  "auto_postpone_period_in_days": 30,
  "url": "http://app.fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm",
  "creator": {
    "id": "03f5v9zjw7pz8717a4no1h8a7",
    "name": "David Heinemeier Hansson",
    "role": "owner",
    "active": true,
    "email_address": "david@example.com",
    "created_at": "2025-12-05T19:36:35.401Z",
    "url": "http://app.fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
  },
  "public_description": "Follow along with public product updates.",
  "public_description_html": "<div class=\"trix-content\"><p>Follow along with public product updates.</p></div>",
  "user_ids": [
    "03f5v9zjw7pz8717a4no1h8a7",
    "03f5v9zppzlksuj4mxba2nbzn"
  ],
  "public_url": "http://app.fizzy.localhost:3006/897362094/public/boards/aB3dEfGhIjKlMnOp"
}
```

The `public_description`, `public_description_html`, and `public_url` fields are only present when the board is published. The `user_ids` field is only present when `all_access` is `false`; use `GET /:account_slug/users` to resolve those IDs to user records if needed.

## `POST /:account_slug/boards`

Creates a new Board in the account.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | The name of the board |
| `all_access` | boolean | No | Whether any user in the account can access this board. Defaults to `true` |
| `auto_postpone_period_in_days` | integer | No | Number of days of inactivity before cards are automatically postponed (e.g. `30`) |
| `public_description` | string | No | Rich text description shown on the public board page |

__Request:__

```json
{
  "board": {
    "name": "My new board"
  }
}
```

__Response:__

Returns `201 Created` with a `Location` header pointing to the new board:

```
HTTP/1.1 201 Created
Location: /897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm.json
```

## `PUT /:account_slug/boards/:board_id`

Updates a Board. Only board administrators can update a board.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | No | The name of the board |
| `all_access` | boolean | No | Whether any user in the account can access this board |
| `auto_postpone_period_in_days` | integer | No | Number of days of inactivity before cards are automatically postponed (e.g. `30`) |
| `public_description` | string | No | Rich text description shown on the public board page |
| `user_ids` | array | No | Array of *all* user IDs who should have access to this board (only applicable when `all_access` is `false`) |

__Request:__

```json
{
  "board": {
    "name": "Updated board name",
    "auto_postpone_period_in_days": 30,
    "public_description": "This is a **public** description of the board.",
    "all_access": false,
    "user_ids": [
      "03f5v9zppzlksuj4mxba2nbzn",
      "03f5v9zjw7pz8717a4no1h8a7"
    ]
  }
}
```

__Response:__

Returns `204 No Content` on success.

## `DELETE /:account_slug/boards/:board_id`

Deletes a Board. Only board administrators can delete a board.

__Response:__

Returns `204 No Content` on success.

## Board Accesses

Board accesses let you see who has access to a board and their involvement level (watching or access only). Any board member can view this information.

### `GET /:account_slug/boards/:board_id/accesses`

Returns a paginated list of active account users with their access status for the specified board.

__Response:__

```json
{
  "board_id": "03f5v9zkft4hj9qq0lsn9ohcm",
  "all_access": false,
  "users": [
    {
      "id": "03f5v9zjw7pz8717a4no1h8a7",
      "name": "David Heinemeier Hansson",
      "role": "owner",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7",
      "avatar_url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7/avatar",
      "has_access": true,
      "involvement": "watching"
    },
    {
      "id": "03f5v9zppzlksuj4mxba2nbzn",
      "name": "Kevin Clark",
      "role": "admin",
      "active": true,
      "email_address": "kevin@example.com",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zppzlksuj4mxba2nbzn",
      "avatar_url": "http://fizzy.localhost:3006/897362094/users/03f5v9zppzlksuj4mxba2nbzn/avatar",
      "has_access": false,
      "involvement": null
    }
  ]
}
```

- `has_access` indicates whether the user has access to the board
- `involvement` is `"watching"`, `"access_only"`, or `null` (when the user does not have access)
- When `all_access` is `true`, all active account users have access to the board
- The `users` array contains the current page of results; if there are more users, follow the `Link` response header with `rel="next"`

To change who has access, use `PUT /:account_slug/boards/:board_id` with the `user_ids` parameter.

## Board Publications

Publishing a board makes it publicly accessible via a shareable link, without requiring authentication. Only board administrators can publish or unpublish a board.

## `POST /:account_slug/boards/:board_id/publication`

Publishes a board, generating a shareable public link.

__Response:__

```
HTTP/1.1 201 Created
```

```json
{
  "id": "03f5v9zkft4hj9qq0lsn9ohcm",
  "name": "Fizzy",
  "all_access": true,
  "created_at": "2025-12-05T19:36:35.534Z",
  "auto_postpone_period_in_days": 30,
  "url": "http://app.fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm",
  "creator": {
    "id": "03f5v9zjw7pz8717a4no1h8a7",
    "name": "David Heinemeier Hansson",
    "role": "owner",
    "active": true,
    "email_address": "david@example.com",
    "created_at": "2025-12-05T19:36:35.401Z",
    "url": "http://app.fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
  },
  "public_url": "http://app.fizzy.localhost:3006/897362094/public/boards/aB3dEfGhIjKlMnOp"
}
```

If the board is already published, the existing publication is returned.

## `DELETE /:account_slug/boards/:board_id/publication`

Unpublishes a board, removing public access.

__Response:__

Returns `204 No Content` on success.
