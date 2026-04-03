# Reactions

## Card Reactions (Boosts)

Card reactions (also called "boosts") let users add short responses directly to cards. These are limited to 16 characters.

## `GET /:account_slug/cards/:card_number/reactions`

Returns a list of reactions on a card.

__Response:__

```json
[
  {
    "id": "03f5v9zo9qlcwwpyc0ascnikz",
    "content": "👍",
    "reacter": {
      "id": "03f5v9zjw7pz8717a4no1h8a7",
      "name": "David Heinemeier Hansson",
      "role": "owner",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
    },
    "url": "http://fizzy.localhost:3006/897362094/cards/3/reactions/03f5v9zo9qlcwwpyc0ascnikz"
  }
]
```

## `POST /:account_slug/cards/:card_number/reactions`

Adds a reaction (boost) to a card.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `content` | string | Yes | The reaction text (max 16 characters) |

__Request:__

```json
{
  "reaction": {
    "content": "Great 👍"
  }
}
```

__Response:__

Returns `201 Created` on success.

## `DELETE /:account_slug/cards/:card_number/reactions/:reaction_id`

Removes your reaction from a card. Only the reaction creator can remove their own reactions.

__Response:__

Returns `204 No Content` on success.

## Comment Reactions

Reactions are short (16-character max) responses to comments.

## `GET /:account_slug/cards/:card_number/comments/:comment_id/reactions`

Returns a list of reactions on a comment.

__Response:__

```json
[
  {
    "id": "03f5v9zo9qlcwwpyc0ascnikz",
    "content": "👍",
    "reacter": {
      "id": "03f5v9zjw7pz8717a4no1h8a7",
      "name": "David Heinemeier Hansson",
      "role": "owner",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
    },
    "url": "http://fizzy.localhost:3006/897362094/cards/3/comments/03f5v9zo9qlcwwpyc0ascnikz/reactions/03f5v9zo9qlcwwpyc0ascnikz"
  }
]
```

## `POST /:account_slug/cards/:card_number/comments/:comment_id/reactions`

Adds a reaction to a comment.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `content` | string | Yes | The reaction text |

__Request:__

```json
{
  "reaction": {
    "content": "Great 👍"
  }
}
```

__Response:__

Returns `201 Created` on success.

## `DELETE /:account_slug/cards/:card_number/comments/:comment_id/reactions/:reaction_id`

Removes your reaction from a comment.

__Response:__

Returns `204 No Content` on success.
