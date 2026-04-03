# Notifications

Notifications inform users about events that happened in the account, such as comments, assignments, and card updates.

## `GET /:account_slug/notifications`

Returns a list of notifications for the current user. Unread notifications are returned first, followed by read notifications.

__Response:__

```json
[
  {
    "id": "03f5va03bpuvkcjemcxl73ho2",
    "read": false,
    "read_at": null,
    "created_at": "2025-11-19T04:03:58.000Z",
    "title": "Plain text mentions",
    "body": "Assigned to self",
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
      "title": "Plain text mentions",
      "status": "published",
      "url": "http://fizzy.localhost:3006/897362094/cards/3"
    },
    "url": "http://fizzy.localhost:3006/897362094/notifications/03f5va03bpuvkcjemcxl73ho2"
  }
]
```

## `POST /:account_slug/notifications/:notification_id/reading`

Marks a notification as read.

__Response:__

Returns `204 No Content` on success.

## `DELETE /:account_slug/notifications/:notification_id/reading`

Marks a notification as unread.

__Response:__

Returns `204 No Content` on success.

## `POST /:account_slug/notifications/bulk_reading`

Marks all unread notifications as read.

__Response:__

Returns `204 No Content` on success.
