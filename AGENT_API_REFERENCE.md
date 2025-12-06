# Agent API & Webhook Reference

This document describes the methods and properties available to agents via the Fizzy REST API and webhooks.

## API Endpoints Available to Agents

### Boards

#### List Boards
```
GET /api/boards
```
Returns a list of all boards accessible to the authenticated user.

**Response Properties:**
- `id` - Board UUID
- `name` - Board name
- `all_access` - Boolean indicating if all users have access
- `created_at`, `updated_at` - ISO8601 timestamps
- `creator` - Object with `id` and `name`
- `columns` - Array of regular column objects, each with:
  - `id` - Column UUID
  - `name` - Column name (use this when creating cards with the `column` parameter)
  - `color` - Column color value (CSS variable format, e.g., "var(--color-card-default)")
- `virtual_columns` - Array of virtual column objects, each with:
  - `name` - Virtual column name ("NOT NOW", "MAYBE?", or "DONE")
  - `description` - Description of what the virtual column represents
  - `is_virtual` - Always `true` to indicate this is not a regular column

**Virtual Columns:**

Fizzy has three special virtual columns that represent card states rather than actual columns:
- **NOT NOW**: Postponed cards (temporarily set aside)
- **MAYBE?**: Cards awaiting triage (not yet assigned to a column)
- **DONE**: Closed cards

These can be used in the `column` parameter when creating cards or `to_column` when moving cards, just like regular column names.

#### Get Board
```
GET /api/boards/:id
```
Returns details for a specific board.

**Response Properties:** Same as List Boards

---

### Cards

#### List Cards
```
GET /api/cards
```

Lists and filters cards accessible to the authenticated user. This endpoint is essential for agents to recover card IDs after restart.

**Query Parameters:**
- `board_id` (optional) - Filter by board UUID
- `assignee_ids[]` (optional) - Array of user UUIDs to filter by assignees
- `creator_ids[]` (optional) - Array of user UUIDs to filter by creators
- `column` (optional) - Column name (case-insensitive) or virtual column: "NOT NOW", "MAYBE?", "DONE"
- `tags[]` (optional) - Array of tag titles to filter by
- `created_at` (optional) - Time window ("today", "yesterday", "thisweek", "thismonth", "thisyear", "lastweek", "lastmonth", "lastyear") or ISO8601 date/datetime
- `status` (optional) - Filter by status: "all" (default), "closed", "not_now"
- `sort` (optional) - Sort order: "latest" (default), "newest", "oldest"

**Response Properties:**
Array of card objects, each with:
- `id` - Card number (sequential integer)
- `title` - Card title
- `description` - Plain text description
- `status` - Status (e.g., "published")
- `column` - Column name or virtual column name ("NOT NOW", "MAYBE?", "DONE") or `null`
- `board_id` - Board UUID
- `tags` - Array of tag titles
- `assignees` - Array of objects with `id` and `name`
- `created_at`, `updated_at` - ISO8601 timestamps

**Usage for Agents:**
Agents can use this endpoint to:
- Find cards they created: `GET /api/cards?creator_ids[]=AGENT_USER_UUID`
- Find cards assigned to them: `GET /api/cards?assignee_ids[]=AGENT_USER_UUID`
- Find cards with specific tags: `GET /api/cards?tags[]=agent:my-agent`
- Recover card IDs after restart by filtering on known criteria (tags, creator, assignee, etc.)

#### Create Card
```
POST /api/boards/:board_id/cards
```

**Request Parameters:**
- `title` (optional) - Card title, defaults to "Untitled"
- `description` (optional) - Card description (plain text)
- `column` (optional) - Column name to place card in. Can be a regular column name or a virtual column: "NOT NOW", "MAYBE?", or "DONE". Column name matching is case-insensitive (e.g., "backlog" will match "Backlog"), but the response returns the original case.
- `tags` (optional) - Array of tag titles (e.g., `["urgent", "bug"]`)

**Response Properties:**
- `id` - Card number (sequential integer)
- `title` - Card title
- `description` - Plain text description
- `status` - Status (e.g., "published")
- `column` - Column name or `null`
- `board_id` - Board UUID
- `tags` - Array of tag titles
- `assignees` - Array of objects with `id` and `name`
- `created_at`, `updated_at` - ISO8601 timestamps

#### Move Card
```
POST /api/cards/:card_id/move
```

**Request Parameters:**
- `to_column` (required) - Column name to move card to. Can be a regular column name or a virtual column: "NOT NOW", "MAYBE?", or "DONE". Column name matching is case-insensitive (e.g., "backlog" will match "Backlog"), but the response returns the original case.

**Response Properties:** Same as Create Card response

#### Close Card
```
POST /api/cards/:card_id/close
```
Closes a card (moves it to "Done").

**Response Properties:** Same as Create Card response

#### Reopen Card
```
POST /api/cards/:card_id/reopen
```
Reopens a closed card.

**Response Properties:** Same as Create Card response

#### Assign Card
```
POST /api/cards/:card_id/assign
```
Assigns or unassigns a user to/from a card (toggles assignment).

**Request Parameters:**
- `user_id` (required) - User UUID to assign/unassign

**Response Properties:** Same as Create Card response

#### Tag Card
```
POST /api/cards/:card_id/tag
```
Adds or removes tags from a card (toggles tags).

**Request Parameters:**
- `tags` (required) - Array of tag titles to toggle

**Response Properties:** Same as Create Card response

---

### Comments

#### Create Comment
```
POST /api/cards/:card_id/comments
```

**Request Parameters:**
- `body` (required) - Comment text (plain text)

**Response Properties:**
- `id` - Comment UUID
- `body` - Plain text comment body
- `card_id` - Card number
- `creator` - Object with `id` and `name`
- `created_at` - ISO8601 timestamp

---

## Webhook Events Available

Webhooks can subscribe to the following event types:

1. **`card_assigned`** - Card assigned to a user
2. **`card_closed`** - Card moved to "Done"
3. **`card_postponed`** - Card moved to "Not Now" (manual action)
4. **`card_auto_postponed`** - Card auto-postponed due to inactivity
5. **`card_board_changed`** - Card moved to a different board
6. **`card_published`** - Card created/published
7. **`card_reopened`** - Closed card reopened
8. **`card_sent_back_to_triage`** - Card moved back to "Maybe?"
9. **`card_triaged`** - Card moved to a column
10. **`card_unassigned`** - User unassigned from card
11. **`comment_created`** - Comment added to a card
12. **`user.mentioned`** - User mentioned in a comment
13. **`card.linked`** - Card referenced/linked in a comment

### Webhook Payload Structure

Each webhook event includes the following structure:

```json
{
  "id": "event_uuid",
  "action": "card_published",
  "created_at": "2025-12-05T12:18:27Z",
  "eventable": {
    // Full card or comment object (see below)
  },
  "board": {
    "id": "board_uuid",
    "name": "Board Name",
    "all_access": true,
    "created_at": "2025-12-05T12:18:18Z",
    "creator": {
      "id": "user_uuid",
      "name": "User Name"
    }
  },
  "creator": {
    "id": "user_uuid",
    "name": "User Name",
    "role": "member",
    "active": true,
    "email_address": "user@example.com",
    "created_at": "2025-12-05T12:18:18Z",
    "url": "https://..."
  }
}
```

### Card Object in Webhooks

When `eventable` is a Card, it includes:

- `id` - Card UUID (not the number)
- `title` - Card title
- `status` - Card status
- `image_url` - Image URL if present, otherwise `null`
- `golden` - Boolean indicating if card is "golden"
- `last_active_at` - UTC timestamp
- `created_at` - UTC timestamp
- `url` - Full card URL
- `board` - Full board object with:
  - `id`, `name`, `all_access`
  - `created_at`
  - `creator` (id, name)
- `column` - Column object or `null` with:
  - `id`, `name`, `color`
  - `created_at`
- `creator` - Full user object with:
  - `id`, `name`, `role`, `active`
  - `email_address`
  - `created_at`, `url`

### Comment Object in Webhooks

When `eventable` is a Comment, it includes:

- `id` - Comment UUID
- `body` - Object with:
  - `plain_text` - Plain text version
  - `html` - HTML version
- `body_plain_text` - Plain text version of the comment
- `mentions` - Array of mention objects, each with:
  - `user_id` - User UUID
  - `username` - Username (derived from email or name)
  - `name` - User's full name
  - `email` - User's email address
- `card_links` - Array of card link objects, each with:
  - `card_id` - Card number
  - `title` - Card title
- `created_at`, `updated_at` - UTC timestamps
- `creator` - Full user object (same structure as above)
- `reactions_url` - URL for comment reactions
- `url` - Comment URL

### user.mentioned Webhook

When `action` is `user.mentioned`, the webhook payload includes:

- Standard webhook structure with `eventable` as the Comment containing the mention
- `target` - Object with:
  - `id` - User UUID of the mentioned user
  - `email` - Email address of the mentioned user
- The `eventable.comment` includes the full `mentions` array

### card.linked Webhook

When `action` is `card.linked`, the webhook payload includes:

- Standard webhook structure with `eventable` as the Comment containing the link
- `linked_card` - Object with:
  - `id` - Card number
  - `title` - Card title
- The `eventable.comment` includes the full `card_links` array

---

## Summary

### Available via API:
✅ Create cards, move cards, close/reopen cards  
✅ Assign/unassign users, manage tags  
✅ Create comments  
✅ List/get boards  
✅ **List and filter cards** - `GET /api/cards` with filters by assignee, creator, column, tags, date, status  
✅ Card properties: `id`, `title`, `description`, `status`, `column`, `board_id`, `tags`, `assignees`, timestamps

### Available via Webhooks:
✅ 11 different event types for card and comment actions  
✅ Full card/comment objects with nested board, column, creator data  
✅ Real-time notifications of all changes

### Not Available:
❌ Card updates (title/description) - Only creation and actions are available  
❌ Reading comments - Only creating them is available

**Recommendation:** 
- Agents should use `GET /api/cards` with filters (creator_ids, assignee_ids, tags) to recover card IDs after restart
- Agents should use webhooks to track card IDs and state changes in real-time
- Use the API to perform actions on those cards

