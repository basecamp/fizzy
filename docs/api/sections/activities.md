# Activities

Activities are the activity stream for an account — a record of significant actions like cards being published, assigned, closed, and commented on.

## `GET /:account_slug/activities`

Returns a paginated flat list of activities the current user can access, sorted newest first.

__Query Parameters:__

| Parameter | Description |
|-----------|-------------|
| `creator_ids[]` | Filter to activities created by specific user ID(s). Multiple values are ORed. |
| `board_ids[]` | Filter to activities on specific board ID(s). Multiple values are ORed. |

Different filter params are ANDed together: `creator_ids[]=A&board_ids[]=X` means activities created by A on board X.

To fetch activity for a specific user, use `creator_ids[]=USER_ID`.

__Supported actions:__

| `action` | `eventable_type` | `particulars` shape |
|----------|-----------------|---------------------|
| `card_assigned` | `Card` | `{ "assignee_ids": [USER_ID, ...] }` |
| `card_auto_postponed` | `Card` | `{}` |
| `card_board_changed` | `Card` | `{ "old_board": STRING, "new_board": STRING }` |
| `card_closed` | `Card` | `{}` |
| `card_postponed` | `Card` | `{}` |
| `card_published` | `Card` | `{}` |
| `card_reopened` | `Card` | `{}` |
| `card_sent_back_to_triage` | `Card` | `{}` |
| `card_title_changed` | `Card` | `{ "old_title": STRING, "new_title": STRING }` |
| `card_triaged` | `Card` | `{ "column": STRING }` |
| `card_unassigned` | `Card` | `{ "assignee_ids": [USER_ID, ...] }` |
| `comment_created` | `Comment` | `{}` |

`particulars` is always an object. It contains action-specific metadata in a normalized format intended for API clients. It does not necessarily mirror the internal event JSON stored by Fizzy. Unknown keys may appear in the future and should be ignored. For `card_assigned` and `card_unassigned`, `assignee_ids` is currently a single-element array in practice.

__`particulars` examples:__

```json
{ "action": "card_assigned", "particulars": { "assignee_ids": ["03f5user123"] } }
{ "action": "card_unassigned", "particulars": { "assignee_ids": ["03f5user123"] } }
{ "action": "card_board_changed", "particulars": { "old_board": "Backlog", "new_board": "Mobile" } }
{ "action": "card_title_changed", "particulars": { "old_title": "Fix login", "new_title": "Fix mobile login" } }
{ "action": "card_triaged", "particulars": { "column": "In Progress" } }
{ "action": "card_closed", "particulars": {} }
```

The practical `eventable_type` values are `Card` and `Comment`. Clients should handle unknown future values conservatively.

Activities whose underlying `Card` or `Comment` has been deleted or is inaccessible to the current user are omitted from the feed. The endpoint never returns `eventable: null`.

The top-level `board` field reflects the activity's current board association. If a card moves boards, all its activities move with it for the purposes of this feed and `board_ids[]` filtering.

This endpoint is a paginated activity feed, not an immutable audit-log. `description`, `eventable`, `board`, and `creator` may reflect current resource state. Re-fetch recent pages to get fresh activity data.

__Response:__

```json
[
  {
    "id": "03faevt004",
    "action": "card_closed",
    "created_at": "2026-03-25T15:11:04.000Z",
    "description": "David Heinemeier Hansson moved \"Fix mobile login\" to \"Done\"",
    "particulars": {},
    "url": "http://app.fizzy.localhost:3006/897362094/cards/42",
    "eventable_type": "Card",
    "eventable": {
      "id": "03f6card042",
      "number": 42,
      "title": "Fix mobile login",
      "status": "closed",
      "description": "Users cannot complete login on iOS.",
      "description_html": "<div>Users cannot complete login on iOS.</div>",
      "image_url": null,
      "has_attachments": false,
      "tags": ["ios", "auth"],
      "closed": true,
      "postponed": false,
      "golden": false,
      "last_active_at": "2026-03-25T15:11:04.000Z",
      "created_at": "2026-03-25T09:00:00.000Z",
      "url": "http://app.fizzy.localhost:3006/897362094/cards/42"
    },
    "board": {
      "id": "03f6abc123",
      "name": "Mobile",
      "all_access": true,
      "created_at": "2026-03-01T10:00:00.000Z",
      "auto_postpone_period_in_days": 14,
      "url": "http://app.fizzy.localhost:3006/897362094/boards/03f6abc123"
    },
    "creator": {
      "id": "03f5user123",
      "name": "David Heinemeier Hansson",
      "role": "owner",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2026-03-01T09:00:00.000Z",
      "url": "http://app.fizzy.localhost:3006/897362094/users/03f5user123",
      "avatar_url": "http://app.fizzy.localhost:3006/897362094/users/03f5user123/avatar"
    }
  },
  {
    "id": "03faevt003",
    "action": "comment_created",
    "created_at": "2026-03-25T14:17:22.000Z",
    "description": "David Heinemeier Hansson commented on \"Fix mobile login\"",
    "particulars": {},
    "url": "http://app.fizzy.localhost:3006/897362094/cards/42#comment_03facomment9",
    "eventable_type": "Comment",
    "eventable": {
      "id": "03facomment9",
      "created_at": "2026-03-25T14:17:22.000Z",
      "updated_at": "2026-03-25T14:17:22.000Z",
      "body": {
        "plain_text": "I found the regression in the callback flow.",
        "html": "<div>I found the regression in the callback flow.</div>"
      },
      "creator": {
        "id": "03f5user123",
        "name": "David Heinemeier Hansson",
        "role": "owner",
        "active": true,
        "email_address": "david@example.com",
        "created_at": "2026-03-01T09:00:00.000Z",
        "url": "http://app.fizzy.localhost:3006/897362094/users/03f5user123",
        "avatar_url": "http://app.fizzy.localhost:3006/897362094/users/03f5user123/avatar"
      },
      "card": {
        "id": "03f6card042",
        "url": "http://app.fizzy.localhost:3006/897362094/cards/42"
      },
      "reactions_url": "http://app.fizzy.localhost:3006/897362094/cards/42/comments/03facomment9/reactions",
      "url": "http://app.fizzy.localhost:3006/897362094/cards/42/comments/03facomment9"
    },
    "board": {
      "id": "03f6abc123",
      "name": "Mobile",
      "all_access": true,
      "created_at": "2026-03-01T10:00:00.000Z",
      "auto_postpone_period_in_days": 14,
      "url": "http://app.fizzy.localhost:3006/897362094/boards/03f6abc123"
    },
    "creator": {
      "id": "03f5user123",
      "name": "David Heinemeier Hansson",
      "role": "owner",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2026-03-01T09:00:00.000Z",
      "url": "http://app.fizzy.localhost:3006/897362094/users/03f5user123",
      "avatar_url": "http://app.fizzy.localhost:3006/897362094/users/03f5user123/avatar"
    }
  }
]
```

All `url` fields are opaque absolute URLs for the current Fizzy instance. Clients should not construct them.
