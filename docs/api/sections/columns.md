# Columns

Columns represent stages in a workflow on a board. Cards move through columns as they progress.

## `GET /:account_slug/boards/:board_id/columns`

Returns a list of columns on a board, sorted by position.

__Response:__

```json
[
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohcm",
    "name": "Recording",
    "color": "var(--color-card-default)",
    "created_at": "2025-12-05T19:36:35.534Z",
    "cards_url": "http://fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm/columns/03f5v9zkft4hj9qq0lsn9ohcm/cards"
  },
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohcn",
    "name": "Published",
    "color": "var(--color-card-4)",
    "created_at": "2025-12-05T19:36:35.534Z",
    "cards_url": "http://fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm/columns/03f5v9zkft4hj9qq0lsn9ohcn/cards"
  }
]
```

## `GET /:account_slug/boards/:board_id/columns/:column_id`

Returns the specified column metadata.

__Response:__

```json
{
  "id": "03f5v9zkft4hj9qq0lsn9ohcm",
  "name": "In Progress",
  "color": "var(--color-card-default)",
  "created_at": "2025-12-05T19:36:35.534Z",
  "cards_url": "http://fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm/columns/03f5v9zkft4hj9qq0lsn9ohcm/cards"
}
```

## `GET /:account_slug/boards/:board_id/columns/:column_id/cards`

Returns a paginated list of open cards in the specified workflow column.
This only includes cards triaged into that column. Cards in "Maybe?", "Not Now", and "Done"
are not included.

The response items have the same shape as `GET /:account_slug/cards`.

__Response:__

```json
[
  {
    "id": "03f5vaeq985jlvwv3arl4srq2",
    "number": 1,
    "title": "First!",
    "status": "published",
    "description": "Hello, World!",
    "description_html": "<div class=\"action-text-content\"><p>Hello, World!</p></div>",
    "image_url": null,
    "has_attachments": false,
    "tags": ["programming"],
    "closed": false,
    "postponed": false,
    "golden": false,
    "last_active_at": "2025-12-05T19:38:48.553Z",
    "created_at": "2025-12-05T19:38:48.540Z",
    "url": "http://fizzy.localhost:3006/897362094/cards/4",
    "board": {
      "id": "03f5v9zkft4hj9qq0lsn9ohcm",
      "name": "Fizzy",
      "all_access": true,
      "created_at": "2025-12-05T19:36:35.534Z",
      "auto_postpone_period_in_days": 30,
      "url": "http://fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm",
      "creator": {
        "id": "03f5v9zjw7pz8717a4no1h8a7",
        "name": "David Heinemeier Hansson",
        "role": "owner",
        "active": true,
        "email_address": "david@example.com",
        "created_at": "2025-12-05T19:36:35.401Z",
        "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7",
        "avatar_url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7/avatar"
      }
    },
    "column": {
      "id": "03f5v9zkft4hj9qq0lsn9ohcn",
      "name": "In Progress",
      "color": "var(--color-card-4)",
      "created_at": "2025-12-05T19:36:35.534Z",
      "cards_url": "http://fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm/columns/03f5v9zkft4hj9qq0lsn9ohcn/cards"
    },
    "creator": {
      "id": "03f5v9zjw7pz8717a4no1h8a7",
      "name": "David Heinemeier Hansson",
      "role": "owner",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7",
      "avatar_url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7/avatar"
    },
    "assignees": [
      {
        "id": "03f5v9zjw7pz8717a4no1h8a7",
        "name": "David Heinemeier Hansson",
        "role": "owner",
        "active": true,
        "email_address": "david@example.com",
        "created_at": "2025-12-05T19:36:35.401Z",
        "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7",
        "avatar_url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7/avatar"
      }
    ],
    "has_more_assignees": false,
    "comments_url": "http://fizzy.localhost:3006/897362094/cards/4/comments",
    "reactions_url": "http://fizzy.localhost:3006/897362094/cards/4/reactions"
  }
]
```

## `POST /:account_slug/boards/:board_id/columns`

Creates a new column on the board.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | The name of the column |
| `color` | string | No | The column color. One of: `var(--color-card-default)` (Blue), `var(--color-card-1)` (Gray), `var(--color-card-2)` (Tan), `var(--color-card-3)` (Yellow), `var(--color-card-4)` (Lime), `var(--color-card-5)` (Aqua), `var(--color-card-6)` (Violet), `var(--color-card-7)` (Purple), `var(--color-card-8)` (Pink) |

__Request:__

```json
{
  "column": {
    "name": "In Progress",
    "color": "var(--color-card-4)"
  }
}
```

__Response:__

Returns `201 Created` with a `Location` header pointing to the new column.

## `PUT /:account_slug/boards/:board_id/columns/:column_id`

Updates a column.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | No | The name of the column |
| `color` | string | No | The column color |

__Request:__

```json
{
  "column": {
    "name": "Done"
  }
}
```

__Response:__

Returns `204 No Content` on success.

## `DELETE /:account_slug/boards/:board_id/columns/:column_id`

Deletes a column.

__Response:__

Returns `204 No Content` on success.
