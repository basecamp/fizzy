# Webhooks

Webhooks notify another application when something happens on a board. Only account admins can list, view, create, update, delete, or reactivate webhooks.

## `GET /:account_slug/boards/:board_id/webhooks`

Returns a paginated list of webhooks for a board.

__Response:__

```json
[
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohcm",
    "name": "Production API",
    "payload_url": "https://api.example.com/webhooks",
    "active": true,
    "signing_secret": "p94Bx2HjempCdYB4DTyZkY1b",
    "subscribed_actions": ["card_published", "card_assigned", "card_closed"],
    "created_at": "2025-12-05T19:36:35.534Z",
    "url": "http://app.fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcy/webhooks/03f5v9zkft4hj9qq0lsn9ohcm",
    "board": {
      "id": "03f5v9zkft4hj9qq0lsn9ohcy",
      "name": "Fizzy",
      "all_access": true,
      "created_at": "2025-12-05T19:36:35.534Z",
      "url": "http://app.fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcy",
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
  }
]
```

## `GET /:account_slug/boards/:board_id/webhooks/:id`

Returns a single webhook.

__Response:__

Returns the same webhook shape shown above.

## `POST /:account_slug/boards/:board_id/webhooks`

Creates a webhook.

__Request:__

```json
{
  "webhook": {
    "name": "Production API",
    "url": "https://api.example.com/webhooks",
    "subscribed_actions": ["card_published", "card_assigned", "card_closed"]
  }
}
```

`subscribed_actions` accepts any of:
`card_assigned`, `card_closed`, `card_postponed`, `card_auto_postponed`, `card_board_changed`, `card_published`, `card_reopened`, `card_sent_back_to_triage`, `card_triaged`, `card_unassigned`, `comment_created`

__Response:__

```
HTTP/1.1 201 Created
Location: http://app.fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcy/webhooks/03f5v9zkft4hj9qq0lsn9ohcm.json
```

Returns the created webhook in the response body.

## `PATCH /:account_slug/boards/:board_id/webhooks/:id`

Updates a webhook.

__Request:__

```json
{
  "webhook": {
    "name": "Production API",
    "subscribed_actions": ["card_closed"]
  }
}
```

The `url` is immutable after creation and is ignored on update.

__Response:__

Returns the updated webhook.

## `DELETE /:account_slug/boards/:board_id/webhooks/:id`

Deletes a webhook.

__Response:__

Returns `204 No Content` on success.

## `POST /:account_slug/boards/:board_id/webhooks/:id/activation`

Reactivates a deactivated webhook.

__Response:__

```
HTTP/1.1 201 Created
```

Returns the reactivated webhook in the response body.

## `GET /:account_slug/boards/:board_id/webhooks/:webhook_id/deliveries`

Returns a paginated list of deliveries for a webhook. Only account admins can access delivery history.

__Response:__

```json
[
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohdn",
    "state": "completed",
    "created_at": "2025-12-05T19:36:35.534Z",
    "updated_at": "2025-12-05T19:36:36.102Z",
    "request": {
      "headers": {
        "User-Agent": "fizzy/1.0.0 Webhook",
        "Content-Type": "application/json",
        "X-Webhook-Timestamp": "2025-12-05T19:36:35.401Z"
      }
    },
    "response": {
      "code": 200,
      "error": null
    },
    "event": {
      "id": "03f5v9zkft4hj9qq0lsn9ohde",
      "action": "card_closed",
      "created_at": "2025-12-05T19:36:35.401Z",
      "creator": {
        "id": "03f5v9zjw7pz8717a4no1h8a7",
        "name": "David Heinemeier Hansson"
      },
      "eventable": {
        "type": "Card",
        "id": "03f5v9zkft4hj9qq0lsn9ohdb",
        "url": "http://app.fizzy.localhost:3006/897362094/cards/1"
      }
    }
  }
]
```

`request` and `response` can be `null` for deliveries that have not started yet or are still in progress. The delivery request headers omit the `X-Webhook-Signature` header.
