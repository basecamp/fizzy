# Comments

Comments are attached to cards and support rich text.

## `GET /:account_slug/cards/:card_number/comments`

Returns a paginated list of comments on a card, sorted chronologically (oldest first).

__Response:__

```json
[
  {
    "id": "03f5v9zo9qlcwwpyc0ascnikz",
    "created_at": "2025-12-05T19:36:35.534Z",
    "updated_at": "2025-12-05T19:36:35.534Z",
    "body": {
      "plain_text": "This looks great!",
      "html": "<div class=\"action-text-content\">This looks great!</div>"
    },
    "creator": {
      "id": "03f5v9zjw7pz8717a4no1h8a7",
      "name": "David Heinemeier Hansson",
      "role": "owner",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
    },
    "card": {
      "id": "03f5v9zo9qlcwwpyc0ascnikz",
      "url": "http://fizzy.localhost:3006/897362094/cards/03f5v9zo9qlcwwpyc0ascnikz"
    },
    "reactions_url": "http://fizzy.localhost:3006/897362094/cards/3/comments/03f5v9zo9qlcwwpyc0ascnikz/reactions",
    "url": "http://fizzy.localhost:3006/897362094/cards/3/comments/03f5v9zo9qlcwwpyc0ascnikz"
  }
]
```

## `GET /:account_slug/cards/:card_number/comments/:comment_id`

Returns a specific comment.

__Response:__

```json
{
  "id": "03f5v9zo9qlcwwpyc0ascnikz",
  "created_at": "2025-12-05T19:36:35.534Z",
  "updated_at": "2025-12-05T19:36:35.534Z",
  "body": {
    "plain_text": "This looks great!",
    "html": "<div class=\"action-text-content\">This looks great!</div>"
  },
  "creator": {
    "id": "03f5v9zjw7pz8717a4no1h8a7",
    "name": "David Heinemeier Hansson",
    "role": "owner",
    "active": true,
    "email_address": "david@example.com",
    "created_at": "2025-12-05T19:36:35.401Z",
    "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
  },
  "card": {
    "id": "03f5v9zo9qlcwwpyc0ascnikz",
    "url": "http://fizzy.localhost:3006/897362094/cards/03f5v9zo9qlcwwpyc0ascnikz"
  },
  "reactions_url": "http://fizzy.localhost:3006/897362094/cards/3/comments/03f5v9zo9qlcwwpyc0ascnikz/reactions",
  "url": "http://fizzy.localhost:3006/897362094/cards/3/comments/03f5v9zo9qlcwwpyc0ascnikz"
}
```

## `POST /:account_slug/cards/:card_number/comments`

Creates a new comment on a card.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `body` | string | Yes | The comment body (supports rich text) |
| `created_at` | datetime | No | Override creation timestamp (ISO 8601 format) |

__Request:__

```json
{
  "comment": {
    "body": "This looks great!"
  }
}
```

__Response:__

Returns `201 Created` with a `Location` header pointing to the new comment.

## `PUT /:account_slug/cards/:card_number/comments/:comment_id`

Updates a comment. Only the comment creator can update their comments.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `body` | string | Yes | The updated comment body |

__Request:__

```json
{
  "comment": {
    "body": "This looks even better now!"
  }
}
```

__Response:__

Returns the updated comment.

## `DELETE /:account_slug/cards/:card_number/comments/:comment_id`

Deletes a comment. Only the comment creator can delete their comments.

__Response:__

Returns `204 No Content` on success.
