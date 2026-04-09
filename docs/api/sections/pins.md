# Pins

Pins let users keep quick access to important cards.

## `POST /:account_slug/cards/:card_number/pin`

Pins a card for the current user.

__Response:__

Returns `204 No Content` on success.

## `DELETE /:account_slug/cards/:card_number/pin`

Unpins a card for the current user.

__Response:__

Returns `204 No Content` on success.

## `GET /my/pins`

Returns the current user's pinned cards. This endpoint is not paginated and returns up to 100 cards.

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
        "url": "http://app.fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7",
        "avatar_url": "http://app.fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7/avatar"
      }
    },
    "creator": {
      "id": "03f5v9zjw7pz8717a4no1h8a7",
      "name": "David Heinemeier Hansson",
      "role": "owner",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://app.fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7",
      "avatar_url": "http://app.fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7/avatar"
    },
    "comments_url": "http://app.fizzy.localhost:3006/897362094/cards/4/comments"
  }
]
```
