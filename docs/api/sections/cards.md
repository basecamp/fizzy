# Cards

Cards are tasks or items of work on a board. They can be organized into columns, tagged, assigned to users, and have comments.

## `GET /:account_slug/cards`

Returns a paginated list of cards you have access to. Results can be filtered using query parameters.

__Query Parameters:__

| Parameter | Description |
|-----------|-------------|
| `board_ids[]` | Filter by board ID(s) |
| `tag_ids[]` | Filter by tag ID(s) |
| `assignee_ids[]` | Filter by assignee user ID(s) |
| `creator_ids[]` | Filter by card creator ID(s) |
| `closer_ids[]` | Filter by user ID(s) who closed the cards |
| `card_ids[]` | Filter to specific card ID(s) |
| `column_ids[]` | Filter by workflow column ID(s) |
| `indexed_by` | Filter by: `all` (default), `maybe`, `closed`, `not_now`, `stalled`, `postponing_soon`, `golden` |
| `sorted_by` | Sort order: `latest` (default), `newest`, `oldest` |
| `assignment_status` | Filter by assignment status: `unassigned` |
| `creation` | Filter by creation date: `today`, `yesterday`, `thisweek`, `lastweek`, `thismonth`, `lastmonth`, `thisyear`, `lastyear` |
| `closure` | Filter by closure date: `today`, `yesterday`, `thisweek`, `lastweek`, `thismonth`, `lastmonth`, `thisyear`, `lastyear` |
| `terms[]` | Search terms to filter cards |

Repeated `column_ids[]` values are ORed together. Other filters combine with AND.

Example:
- `column_ids[]=03f...` — cards in a workflow column by ID

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
    "golden": false,
    "last_active_at": "2025-12-05T19:38:48.553Z",
    "created_at": "2025-12-05T19:38:48.540Z",
    "url": "http://app.fizzy.localhost:3006/897362094/cards/4",
    "board": {
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
    },
    "creator": {
      "id": "03f5v9zjw7pz8717a4no1h8a7",
      "name": "David Heinemeier Hansson",
      "role": "owner",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://app.fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
    },
    "comments_url": "http://app.fizzy.localhost:3006/897362094/cards/4/comments",
    "reactions_url": "http://app.fizzy.localhost:3006/897362094/cards/4/reactions"
  }
]
```

## `GET /:account_slug/cards/:card_number`

Returns a specific card by its number.

__Response:__

```json
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
  "golden": false,
  "last_active_at": "2025-12-05T19:38:48.553Z",
  "created_at": "2025-12-05T19:38:48.540Z",
  "url": "http://app.fizzy.localhost:3006/897362094/cards/4",
  "board": {
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
  },
  "column": {
    "id": "03f5v9zkft4hj9qq0lsn9ohcn",
    "name": "In Progress",
    "color": {
      "name": "Lime",
      "value": "var(--color-card-4)"
    },
    "created_at": "2025-12-05T19:36:35.534Z"
  },
  "creator": {
    "id": "03f5v9zjw7pz8717a4no1h8a7",
    "name": "David Heinemeier Hansson",
    "role": "owner",
    "active": true,
    "email_address": "david@example.com",
    "created_at": "2025-12-05T19:36:35.401Z",
    "url": "http://app.fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
  },
  "comments_url": "http://app.fizzy.localhost:3006/897362094/cards/4/comments",
  "reactions_url": "http://app.fizzy.localhost:3006/897362094/cards/4/reactions",
  "steps": [
    {
      "id": "03f8huu0sog76g3s975963b5e",
      "content": "This is the first step",
      "completed": false
    },
    {
      "id": "03f8huu0sog76g3s975969734",
      "content": "This is the second step",
      "completed": false
    }
  ]
}
```

> **Note:** The `closed` field indicates whether the card is in the "Done" state. The `column` field is only present when the card has been triaged into a column; cards in "Maybe?", "Not Now" or "Done" will not have this field.

## `POST /:account_slug/boards/:board_id/cards`

Creates a new card in a board.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | string | Yes | The title of the card |
| `description` | string | No | Rich text description of the card |
| `status` | string | No | Initial status: `published` (default), `drafted` |
| `image` | file | No | Header image for the card |
| `tag_ids` | array | No | Array of tag IDs to apply to the card |
| `created_at` | datetime | No | Override creation timestamp (ISO 8601 format) |
| `last_active_at` | datetime | No | Override last activity timestamp (ISO 8601 format) |

__Request:__

```json
{
  "card": {
    "title": "Add dark mode support",
    "description": "We need to add dark mode to the app"
  }
}
```

__Response:__

Returns `201 Created` with a `Location` header pointing to the new card.

## `PUT /:account_slug/cards/:card_number`

Updates a card.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | string | No | The title of the card |
| `description` | string | No | Rich text description of the card |
| `status` | string | No | Card status: `drafted`, `published` |
| `image` | file | No | Header image for the card |
| `tag_ids` | array | No | Array of tag IDs to apply to the card |
| `last_active_at` | datetime | No | Override last activity timestamp (ISO 8601 format) |

__Request:__

```json
{
  "card": {
    "title": "Add dark mode support (Updated)"
  }
}
```

__Response:__

Returns the updated card.

## `DELETE /:account_slug/cards/:card_number`

Deletes a card. Only the card creator or board administrators can delete cards.

__Response:__

Returns `204 No Content` on success.

## `DELETE /:account_slug/cards/:card_number/image`

Removes the header image from a card.

__Response:__

Returns `204 No Content` on success.

## `POST /:account_slug/cards/:card_number/closure`

Closes a card.

__Response:__

Returns `204 No Content` on success.

## `DELETE /:account_slug/cards/:card_number/closure`

Reopens a closed card.

__Response:__

Returns `204 No Content` on success.

## `POST /:account_slug/cards/:card_number/not_now`

Moves a card to "Not Now" status.

__Response:__

Returns `204 No Content` on success.

## `PUT /:account_slug/cards/:card_number/board`

Moves a card to a different board.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `board_id` | string | Yes | The ID of the board to move the card to |

__Request:__

```json
{
  "board_id": "03f5v9zkft4hj9qq0lsn9ohcm"
}
```

__Response:__

Returns `200 OK` with the moved card in the same shape as `GET /:account_slug/cards/:card_number`. The `board` field reflects the new board.

## `POST /:account_slug/cards/:card_number/triage`

Moves a card into a column.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `column_id` | string | Yes | The ID of the column to move the card into |

__Response:__

Returns `204 No Content` on success.

## `DELETE /:account_slug/cards/:card_number/triage`

Sends a card back to triage.

__Response:__

Returns `204 No Content` on success.

## `POST /:account_slug/cards/:card_number/taggings`

Toggles a tag on or off for a card. If the tag doesn't exist, it will be created.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `tag_title` | string | Yes | The title of the tag (leading `#` is stripped) |

__Response:__

Returns `204 No Content` on success.

## `POST /:account_slug/cards/:card_number/assignments`

Toggles assignment of a user to/from a card.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `assignee_id` | string | Yes | The ID of the user to assign/unassign |

__Response:__

Returns `204 No Content` on success.

## `POST /:account_slug/cards/:card_number/watch`

Subscribes the current user to notifications for this card.

__Response:__

Returns `204 No Content` on success.

## `DELETE /:account_slug/cards/:card_number/watch`

Unsubscribes the current user from notifications for this card.

__Response:__

Returns `204 No Content` on success.

## `POST /:account_slug/cards/:card_number/goldness`

Marks a card as golden.

__Response:__

Returns `204 No Content` on success.

## `DELETE /:account_slug/cards/:card_number/goldness`

Removes golden status from a card.

__Response:__

Returns `204 No Content` on success.
