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
    "created_at": "2025-12-05T19:36:35.534Z"
  },
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohcn",
    "name": "Published",
    "color": "var(--color-card-4)",
    "created_at": "2025-12-05T19:36:35.534Z"
  }
]
```

## `GET /:account_slug/boards/:board_id/columns/:column_id`

Returns the specified column.

__Response:__

```json
{
  "id": "03f5v9zkft4hj9qq0lsn9ohcm",
  "name": "In Progress",
  "color": "var(--color-card-default)",
  "created_at": "2025-12-05T19:36:35.534Z"
}
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
