# Fizzy API

Fizzy has an API that allows you to integrate your application with it or to create
a bot to perform various actions for you.

## Authentication

There are two ways to authenticate with the Fizzy API:

1. **Personal access tokens** - Long-lived tokens for scripts and integrations
2. **Magic link authentication** - Session-based authentication for native apps

### Personal Access Tokens

To use the API you'll need an access token. To get one, go to your profile, then,
in the API section, click on "Personal access tokens" and then click on
"Generate new access token".

Give it a description and pick what kind of permission you want the access token to have:
- `Read`: allows reading data from your account
- `Read + Write`: allows reading and writing data to your account on your behalf

Then click on "Generate access token".

<details>
  <summary>Access token generation guide with screenshots</summary>

  | Step | Description | Screenshot |
  |:----:|-------------|:----------:|
  | 1 | Go to your profile | <img width="400" alt="Profile page with API section" src="https://github.com/user-attachments/assets/49e7e12b-2952-4220-84fd-cef99b13bc04" /> |
  | 2 | In the API section click on "Personal access token" | <img width="400" alt="Personal access tokens page" src="https://github.com/user-attachments/assets/2f026ea0-416f-4fbe-a097-61313f24f180" /> |
  | 3 | Click on "Generate a new access token" | <img width="400" alt="Generate new access token dialog" src="https://github.com/user-attachments/assets/d766f047-8628-416d-8e21-b89522f6c0d9" /> |
  | 4 | Give it a description and assign it a permission | <img width="400" alt="Access token created" src="https://github.com/user-attachments/assets/49b8e350-d152-4946-8aad-e13260b983fd" /> |
</details>

> [!IMPORTANT]
> __An access token is like a password, keep it secret and do not share it with anyone.__
> Any person or application that has your access token can perform actions on your behalf.

To authenticate a request using your access token, include it in the `Authorization` header:

```bash
curl -H "Authorization: Bearer put-your-access-token-here" -H "Accept: application/json" https://app.fizzy.do/my/identity
```

### Magic Link Authentication

For native apps, you can authenticate users via magic links. This is a two-step process:

#### 1. Request a magic link

Send the user's email address to request a magic link be sent to them:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"email_address": "user@example.com"}' \
  https://app.fizzy.do/session
```

__Response:__

```
HTTP/1.1 201 Created
Set-Cookie: pending_authentication_token=...; HttpOnly; SameSite=Lax
```

```json
{
  "pending_authentication_token": "eyJfcmFpbHMi..."
}
```

The response includes a `pending_authentication_token` both in the JSON body and as a cookie.
Native apps should store this token and include it as a cookie when submitting the magic link code.

__Error responses:__

| Status Code | Description |
|--------|-------------|
| `422 Unprocessable entity` | Invalid email address, if sign ups are enabled and the value isn't a valid email address |
| `429 Too Many Requests` | Rate limit exceeded |

#### 2. Submit the magic link code

Once the user receives the magic link email, they'll have a 6-character code. Submit it to complete authentication:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Cookie: pending_authentication_token=eyJfcmFpbHMi..." \
  -d '{"code": "ABC123"}' \
  https://app.fizzy.do/session/magic_link
```

__Response:__

```json
{
  "session_token": "eyJfcmFpbHMi..."
}
```

The `session_token` can be used to authenticate subsequent requests by including it as a cookie:

```bash
curl -H "Cookie: session_token=eyJfcmFpbHMi..." \
  -H "Accept: application/json" \
  https://app.fizzy.do/my/identity
```

__Error responses:__

| Status Code | Description |
|--------|-------------|
| `401 Unauthorized` | Invalid `pending_authentication_token` or `code` |
| `429 Too Many Requests` | Rate limit exceeded |


#### Delete server-side session (_log out_)

To log out and destroy the server-side session:

```bash
curl -X DELETE \
  -H "Accept: application/json" \
  -H "Cookie: session_token=eyJfcmFpbHMi..." \
  https://app.fizzy.do/session
```

__Response:__

Returns `204 No Content` on success.

## Caching

Most endpoints return [ETag](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/ETag) and [Cache-Control](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cache-Control) headers. You can use these to avoid re-downloading unchanged data.

### Using ETags

When you make a request, the response includes an `ETag` header:

```
HTTP/1.1 200 OK
ETag: "abc123"
Cache-Control: max-age=0, private, must-revalidate
```

On subsequent requests, include the ETag value in the `If-None-Match` header:

```
GET /1234567/cards/42.json
If-None-Match: "abc123"
```

If the resource hasn't changed, you'll receive a `304 Not Modified` response with no body, saving bandwidth and processing time:

```
HTTP/1.1 304 Not Modified
ETag: "abc123"
```

If the resource has changed, you'll receive the full response with a new ETag.

__Example in Ruby:__

```ruby
# Store the ETag from the response
etag = response.headers["ETag"]

# On next request, send it back
headers = { "If-None-Match" => etag }
response = client.get("/1234567/cards/42.json", headers: headers)

if response.status == 304
  # Nothing to do, the card hasn't changed
else
  # The card has changed, process the new data
end
```

## Error Responses

When a request fails, the API response will communicate the source of the problem through the HTTP status code.

| Status Code | Description |
|-------------|-------------|
| `400 Bad Request` | The request was malformed or missing required parameters |
| `401 Unauthorized` | Authentication failed or access token is invalid |
| `403 Forbidden` | You don't have permission to perform this action |
| `404 Not Found` | The requested resource doesn't exist or you don't have access to it |
| `422 Unprocessable Entity` | Validation failed (see error response format below) |
| `429 Too Many Requests` | Rate limit exceeded (see endpoint-specific limits) |
| `500 Internal Server Error` | An unexpected error occurred on the server |

### Endpoint-Specific Error Codes

| Endpoint | 403 | 422 | 429 |
|----------|-----|-----|-----|
| `POST /:account_slug/account/exports` | | | ✓ Max 10 concurrent |
| `PUT /:account_slug/users/:id` | ✓ Not your profile or admin | ✓ Validation errors | |
| `DELETE /:account_slug/users/:id` | ✓ Not your profile or admin | | |
| `PUT /:account_slug/users/:id/role` | ✓ Not admin | | |
| `DELETE /:account_slug/cards/:card_number` | ✓ Not card admin | | |
| `POST /:account_slug/cards/:card_number/assignments` | | ✓ Invalid assignee | |
| `DELETE /:account_slug/cards/:card_number/comments/:comment_id` | ✓ Not comment creator | | |
| `DELETE /:account_slug/cards/:card_number/comments/:comment_id/reactions/:reaction_id` | ✓ Not reaction creator | | |
| `PUT /:account_slug/account/join_code` | | ✓ Validation errors | |

If a request contains invalid data for fields, such as entering a string into a number field, in most cases the API will respond with a `500 Internal Server Error`. Clients are expected to perform some validation on their end before making a request.

A validation error will produce a `422 Unprocessable Entity` response, which will sometimes be accompanied by details about the error:

```json
{
  "avatar": ["must be a JPEG, PNG, GIF, or WebP image"]
}
```

## Pagination

All endpoints that return a list of items are paginated. The page size can vary from endpoint to endpoint,
and we use a dynamic page size where initial pages return fewer results than later pages.

If there are more results to fetch, the response will include a `Link` header with a `rel="next"` link to the next page of results:

```bash
curl -H "Authorization: Bearer put-your-access-token-here" -H "Accept: application/json" -v http://fizzy.localhost:3006/686465299/cards
# ...
< link: <http://fizzy.localhost:3006/686465299/cards?page=2>; rel="next"
# ...
```

## List parameters

When an endpoint accepts a list of values as a parameter, you can provide multiple values by repeating the parameter name:

```
?tag_ids[]=tag1&tag_ids[]=tag2&tag_ids[]=tag3
```

List parameters always end with `[]`.

## File Uploads

Some endpoints accept file uploads. To upload a file, send a `multipart/form-data` request instead of JSON.
You can combine file uploads with other parameters in the same request.

__Example using curl:__

```bash
curl -X PUT \
  -H "Authorization: Bearer put-your-access-token-here" \
  -F "user[name]=David H. Hansson" \
  -F "user[avatar]=@/path/to/avatar.jpg" \
  http://fizzy.localhost:3006/686465299/users/03f5v9zjw7pz8717a4no1h8a7
```

## Rich Text Fields

Some fields accept rich text content. These fields accept HTML input, which will be sanitized to remove unsafe tags and attributes.

```json
{
  "card": {
    "title": "My card",
    "description": "<p>This is <strong>bold</strong> and this is <em>italic</em>.</p><ul><li>Item 1</li><li>Item 2</li></ul>"
  }
}
```

### Attaching files to rich text

To attach files (images, documents) to rich text fields, use ActionText's direct upload flow:

#### 1. Create a direct upload

First, request a direct upload URL by sending file metadata:

```bash
curl -X POST \
  -H "Authorization: Bearer put-your-access-token-here" \
  -H "Content-Type: application/json" \
  -d '{
    "blob": {
      "filename": "screenshot.png",
      "byte_size": 12345,
      "checksum": "GQ5SqLsM7ylnji0Wgd9wNA==",
      "content_type": "image/png"
    }
  }' \
  https://app.fizzy.do/123456/rails/active_storage/direct_uploads
```

The `checksum` is a Base64-encoded MD5 hash of the file content.
The direct upload endpoint is scoped to your account (replace `/123456` with your account slug).

__Response:__

```json
{
  "id": "abc123",
  "key": "abc123def456",
  "filename": "screenshot.png",
  "content_type": "image/png",
  "byte_size": 12345,
  "checksum": "GQ5SqLsM7ylnji0Wgd9wNA==",
  "direct_upload": {
    "url": "https://storage.example.com/...",
    "headers": {
      "Content-Type": "image/png",
      "Content-MD5": "GQ5SqLsM7ylnji0Wgd9wNA=="
    }
  },
  "signed_id": "eyJfcmFpbHMi..."
}
```

#### 2. Upload the file

Upload the file directly to the provided URL with the specified headers:

```bash
curl -X PUT \
  -H "Content-Type: image/png" \
  -H "Content-MD5: GQ5SqLsM7ylnji0Wgd9wNA==" \
  --data-binary @screenshot.png \
  "https://storage.example.com/..."
```

#### 3. Reference the file in rich text

Use the `signed_id` from step 1 to embed the file in your rich text using an `<action-text-attachment>` tag:

```json
{
  "card": {
    "title": "Card with image",
    "description": "<p>Here's a screenshot:</p><action-text-attachment sgid=\"eyJfcmFpbHMi...\"></action-text-attachment>"
  }
}
```

The `sgid` attribute should contain the `signed_id` returned from the direct upload response.

## Identity

An Identity represents a person using Fizzy.

### `GET /my/identity`

Returns a list of accounts the identity has access to, including the user for each account.

```json
{
  "accounts": [
    {
      "id": "03f5v9zjskhcii2r45ih3u1rq",
      "name": "37signals",
      "slug": "/897362094",
      "created_at": "2025-12-05T19:36:35.377Z",
      "user": {
        "id": "03f5v9zjw7pz8717a4no1h8a7",
        "name": "David Heinemeier Hansson",
        "role": "owner",
        "active": true,
        "email_address": "david@example.com",
        "created_at": "2025-12-05T19:36:35.401Z",
        "url": "http://fizzy.localhost:3006/users/03f5v9zjw7pz8717a4no1h8a7"
      }
    },
    {
      "id": "03f5v9zpko7mmhjzwum3youpp",
      "name": "Honcho",
      "slug": "/686465299",
      "created_at": "2025-12-05T19:36:36.746Z",
      "user": {
        "id": "03f5v9zppzlksuj4mxba2nbzn",
        "name": "David Heinemeier Hansson",
        "role": "owner",
        "active": true,
        "email_address": "david@example.com",
        "created_at": "2025-12-05T19:36:36.783Z",
        "url": "http://fizzy.localhost:3006/users/03f5v9zppzlksuj4mxba2nbzn"
      }
    }
  ]
}
```

## Boards

Boards are where you organize your work - they contain your cards.

### `GET /:account_slug/boards`

Returns a list of boards that you can access in the specified account.

__Response:__

```json
[
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohcm",
    "name": "Fizzy",
    "all_access": true,
    "created_at": "2025-12-05T19:36:35.534Z",
    "url": "http://fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm",
    "creator": {
      "id": "03f5v9zjw7pz8717a4no1h8a7",
      "name": "David Heinemeier Hansson",
      "role": "owner",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
    }
  }
]
```

### `GET /:account_slug/boards/:board_id`

Returns the specified board.

__Response:__

```json
{
  "id": "03f5v9zkft4hj9qq0lsn9ohcm",
  "name": "Fizzy",
  "all_access": true,
  "created_at": "2025-12-05T19:36:35.534Z",
  "url": "http://fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm",
  "creator": {
    "id": "03f5v9zjw7pz8717a4no1h8a7",
    "name": "David Heinemeier Hansson",
    "role": "owner",
    "active": true,
    "email_address": "david@example.com",
    "created_at": "2025-12-05T19:36:35.401Z",
    "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
  }
}
```

### `POST /:account_slug/boards`

Creates a new Board in the account.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | The name of the board |
| `all_access` | boolean | No | Whether any user in the account can access this board. Defaults to `true` |
| `auto_postpone_period` | integer | No | Number of days of inactivity before cards are automatically postponed |
| `public_description` | string | No | Rich text description shown on the public board page |

__Request:__

```json
{
  "board": {
    "name": "My new board",
  }
}
```

__Response:__

Returns `201 Created` with a `Location` header pointing to the new board:

```
HTTP/1.1 201 Created
Location: /897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm.json
```

### `PUT /:account_slug/boards/:board_id`

Updates a Board. Only board administrators can update a board.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `board[name]` | string | No | The name of the board |
| `board[all_access]` | boolean | No | Whether any user in the account can access this board |
| `board[auto_postpone_period]` | integer | No | Number of days of inactivity before cards are automatically postponed |
| `board[public_description]` | string | No | Rich text description shown on the public board page |
| `user_ids` | array | No | Array of *all* user IDs who should have access to this board (top-level parameter, only applicable when `all_access` is `false`) |

__Request:__

```json
{
  "board": {
    "name": "Updated board name",
    "auto_postpone_period": 14,
    "public_description": "This is a **public** description of the board.",
    "all_access": false
  },
  "user_ids": [
    "03f5v9zppzlksuj4mxba2nbzn",
    "03f5v9zjw7pz8717a4no1h8a7"
  ]
}
```

__Response:__

Returns `204 No Content` on success.

### `DELETE /:account_slug/boards/:board_id`

Deletes a Board. Only board administrators can delete a board.

__Response:__

Returns `204 No Content` on success.

### `POST /:account_slug/boards/:board_id/publication`

Publishes a board publicly. Once published, the board can be viewed by anyone with the shareable link.

__Response:__

```json
{
  "key": "abc123def456",
  "url": "https://app.fizzy.do/public/boards/abc123def456"
}
```

The `key` is the shareable identifier and `url` is the full public URL.

### `DELETE /:account_slug/boards/:board_id/publication`

Unpublishes a board. The board will no longer be accessible via its public link.

__Response:__

Returns `204 No Content` on success.

### `PUT /:account_slug/boards/:board_id/entropy`

Updates the auto-postpone settings for a board. Cards on this board that have been inactive for the specified period will be automatically moved to "Not Now".

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `auto_postpone_period` | integer | No | Number of days of inactivity before cards are automatically postponed. Set to `null` to use the account default. |

__Request:__

```json
{
  "board": {
    "auto_postpone_period": 14
  }
}
```

__Response:__

Returns `204 No Content` on success.

## Cards

Cards are tasks or items of work on a board. They can be organized into columns, tagged, assigned to users, and have comments.

### `GET /:account_slug/cards`

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
| `indexed_by` | Filter by: `all` (default), `closed`, `not_now`, `stalled`, `postponing_soon`, `golden` |
| `sorted_by` | Sort order: `latest` (default), `newest`, `oldest` |
| `assignment_status` | Filter by assignment status: `unassigned` |
| `creation` | Filter by creation date: `today`, `yesterday`, `thisweek`, `lastweek`, `thismonth`, `lastmonth`, `thisyear`, `lastyear` |
| `closure` | Filter by closure date: `today`, `yesterday`, `thisweek`, `lastweek`, `thismonth`, `lastmonth`, `thisyear`, `lastyear` |
| `terms[]` | Search terms to filter cards |

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
    "tags": ["programming"],
    "closed": false,
    "golden": false,
    "last_active_at": "2025-12-05T19:38:48.553Z",
    "created_at": "2025-12-05T19:38:48.540Z",
    "url": "http://fizzy.localhost:3006/897362094/cards/4",
    "board": {
      "id": "03f5v9zkft4hj9qq0lsn9ohcm",
      "name": "Fizzy",
      "all_access": true,
      "created_at": "2025-12-05T19:36:35.534Z",
      "url": "http://fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm",
      "creator": {
        "id": "03f5v9zjw7pz8717a4no1h8a7",
        "name": "David Heinemeier Hansson",
        "role": "owner",
        "active": true,
        "email_address": "david@example.com",
        "created_at": "2025-12-05T19:36:35.401Z",
        "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
      }
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
    "assignees": [],
    "has_more_assignees": false,
    "comments_url": "http://fizzy.localhost:3006/897362094/cards/4/comments",
    "reactions_url": "http://fizzy.localhost:3006/897362094/cards/4/reactions"
  },
]
```

### `GET /:account_slug/cards/:card_number`

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
  "tags": ["programming"],
  "closed": false,
  "golden": false,
  "last_active_at": "2025-12-05T19:38:48.553Z",
  "created_at": "2025-12-05T19:38:48.540Z",
  "url": "http://fizzy.localhost:3006/897362094/cards/4",
  "board": {
    "id": "03f5v9zkft4hj9qq0lsn9ohcm",
    "name": "Fizzy",
    "all_access": true,
    "created_at": "2025-12-05T19:36:35.534Z",
    "url": "http://fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm",
    "creator": {
      "id": "03f5v9zjw7pz8717a4no1h8a7",
      "name": "David Heinemeier Hansson",
      "role": "owner",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
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
    "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
  },
  "assignees": [
    {
      "id": "03f5v9zjysoy0fqs9yg0ei3hq",
      "name": "Jason Fried",
      "role": "member",
      "active": true,
      "email_address": "jason@example.com",
      "created_at": "2025-12-05T19:36:35.419Z",
      "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjysoy0fqs9yg0ei3hq"
    }
  ],
  "has_more_assignees": false,
  "comments_url": "http://fizzy.localhost:3006/897362094/cards/4/comments",
  "reactions_url": "http://fizzy.localhost:3006/897362094/cards/4/reactions",
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

> **Note:** The `closed` field indicates whether the card is in the "Done" state. The `column` field is only present when the card has been triaged into a column; cards in "Maybe?", "Not Now" or "Done" will not have this field. The `assignees` array includes up to 5 assigned users; when there are more, `has_more_assignees` is `true`.

### `POST /:account_slug/boards/:board_id/cards`

Creates a new card in a board.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | string | Yes | The title of the card |
| `description` | string | No | Rich text description of the card |
| `image` | file | No | Header image for the card |
| `created_at` | datetime | No | Override creation timestamp (ISO 8601 format) |
| `last_active_at` | datetime | No | Override last activity timestamp (ISO 8601 format) |

> **Note:** Cards created via the API are automatically published. To tag a card, use the `POST /:account_slug/cards/:card_number/taggings` endpoint after creation.

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

### `PUT /:account_slug/cards/:card_number`

Updates a card.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | string | No | The title of the card |
| `description` | string | No | Rich text description of the card |
| `image` | file | No | Header image for the card |
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

### `DELETE /:account_slug/cards/:card_number`

Deletes a card. Only the card creator or board administrators can delete cards.

__Response:__

Returns `204 No Content` on success.

### `DELETE /:account_slug/cards/:card_number/image`

Removes the header image from a card.

__Response:__

Returns `204 No Content` on success.

### `POST /:account_slug/cards/:card_number/closure`

Closes a card.

__Response:__

Returns `204 No Content` on success.

### `DELETE /:account_slug/cards/:card_number/closure`

Reopens a closed card.

__Response:__

Returns `204 No Content` on success.

### `POST /:account_slug/cards/:card_number/not_now`

Moves a card to "Not Now" status.

__Response:__

Returns `204 No Content` on success.

### `POST /:account_slug/cards/:card_number/triage`

Moves a card from triage into a column.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `column_id` | string | Yes | The ID of the column to move the card into |

__Response:__

Returns `204 No Content` on success.

### `DELETE /:account_slug/cards/:card_number/triage`

Sends a card back to triage.

__Response:__

Returns `204 No Content` on success.

### `POST /:account_slug/cards/:card_number/taggings`

Toggles a tag on or off for a card. If the tag doesn't exist, it will be created.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `tag_title` | string | Yes | The title of the tag (leading `#` is stripped) |

__Response:__

Returns `204 No Content` on success.

### `POST /:account_slug/cards/:card_number/assignments`

Toggles assignment of a user to/from a card.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `assignee_id` | string | Yes | The ID of the user to assign/unassign |

__Response:__

Returns `204 No Content` on success.

### `POST /:account_slug/cards/:card_number/watch`

Subscribes the current user to notifications for this card.

__Response:__

Returns `204 No Content` on success.

### `DELETE /:account_slug/cards/:card_number/watch`

Unsubscribes the current user from notifications for this card.

__Response:__

Returns `204 No Content` on success.

### `POST /:account_slug/cards/:card_number/goldness`

Marks a card as golden.

__Response:__

Returns `204 No Content` on success.

### `DELETE /:account_slug/cards/:card_number/goldness`

Removes golden status from a card.

__Response:__

Returns `204 No Content` on success.

### `POST /:account_slug/cards/:card_number/publish`

Publishes a drafted card. Cards with `status: drafted` are only visible to their creator until published.

__Response:__

Returns `204 No Content` on success.

### `PUT /:account_slug/cards/:card_number/board`

Moves a card to a different board.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `board_id` | string | Yes | The ID of the target board (top-level parameter) |

__Request:__

```json
{
  "board_id": "03f5v9zkft4hj9qq0lsn9ohcm"
}
```

__Response:__

Returns `204 No Content` on success.

## Pins

Pins let users keep quick access to important cards.

### `POST /:account_slug/cards/:card_number/pin`

Pins a card for the current user.

__Response:__

Returns `204 No Content` on success.

### `DELETE /:account_slug/cards/:card_number/pin`

Unpins a card for the current user.

__Response:__

Returns `204 No Content` on success.

### `GET /my/pins`

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
    "tags": ["programming"],
    "golden": false,
    "last_active_at": "2025-12-05T19:38:48.553Z",
    "created_at": "2025-12-05T19:38:48.540Z",
    "url": "http://fizzy.localhost:3006/897362094/cards/4",
    "board": {
      "id": "03f5v9zkft4hj9qq0lsn9ohcm",
      "name": "Fizzy",
      "all_access": true,
      "created_at": "2025-12-05T19:36:35.534Z",
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
    "comments_url": "http://fizzy.localhost:3006/897362094/cards/4/comments"
  }
]
```

## Comments

Comments are attached to cards and support rich text.

### `GET /:account_slug/cards/:card_number/comments`

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

### `GET /:account_slug/cards/:card_number/comments/:comment_id`

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

### `POST /:account_slug/cards/:card_number/comments`

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

### `PUT /:account_slug/cards/:card_number/comments/:comment_id`

Updates a comment. Only the comment creator can update their comments.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `body` | string | No | The updated comment body |
| `created_at` | datetime | No | Override creation timestamp (ISO 8601 format) |

__Request:__

```json
{
  "comment": {
    "body": "This looks even better now!"
  }
}
```

__Response:__

Returns `204 No Content` on success.

### `DELETE /:account_slug/cards/:card_number/comments/:comment_id`

Deletes a comment. Only the comment creator can delete their comments.

__Response:__

Returns `204 No Content` on success.

## Card Reactions (Boosts)

Card reactions (also called "boosts") let users add short responses directly to cards. These are limited to 16 characters.

### `GET /:account_slug/cards/:card_number/reactions`

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

### `POST /:account_slug/cards/:card_number/reactions`

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

### `DELETE /:account_slug/cards/:card_number/reactions/:reaction_id`

Removes your reaction from a card. Only the reaction creator can remove their own reactions.

__Response:__

Returns `204 No Content` on success.

## Comment Reactions

Reactions are short (16-character max) responses to comments.

### `GET /:account_slug/cards/:card_number/comments/:comment_id/reactions`

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

### `POST /:account_slug/cards/:card_number/comments/:comment_id/reactions`

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

### `DELETE /:account_slug/cards/:card_number/comments/:comment_id/reactions/:reaction_id`

Removes your reaction from a comment.

__Response:__

Returns `204 No Content` on success.

## Steps

Steps are to-do items on a card.

### `GET /:account_slug/cards/:card_number/steps/:step_id`

Returns a specific step.

__Response:__

```json
{
  "id": "03f5v9zo9qlcwwpyc0ascnikz",
  "content": "Write tests",
  "completed": false
}
```

### `POST /:account_slug/cards/:card_number/steps`

Creates a new step on a card.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `content` | string | Yes | The step text |
| `completed` | boolean | No | Whether the step is completed (default: `false`) |

__Request:__

```json
{
  "step": {
    "content": "Write tests"
  }
}
```

__Response:__

Returns `201 Created` with a `Location` header pointing to the new step.

### `PUT /:account_slug/cards/:card_number/steps/:step_id`

Updates a step.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `content` | string | No | The step text |
| `completed` | boolean | No | Whether the step is completed |

__Request:__

```json
{
  "step": {
    "completed": true
  }
}
```

__Response:__

Returns the updated step.

### `DELETE /:account_slug/cards/:card_number/steps/:step_id`

Deletes a step.

__Response:__

Returns `204 No Content` on success.

## Tags

Tags are labels that can be applied to cards for organization and filtering.

### `GET /:account_slug/tags`

Returns a list of all tags in the account, sorted alphabetically.

__Response:__

```json
[
  {
    "id": "03f5v9zo9qlcwwpyc0ascnikz",
    "title": "bug",
    "created_at": "2025-12-05T19:36:35.534Z",
    "url": "http://fizzy.localhost:3006/897362094/cards?tag_ids[]=03f5v9zo9qlcwwpyc0ascnikz"
  },
  {
    "id": "03f5v9zo9qlcwwpyc0ascnilz",
    "title": "feature",
    "created_at": "2025-12-05T19:36:35.534Z",
    "url": "http://fizzy.localhost:3006/897362094/cards?tag_ids[]=03f5v9zo9qlcwwpyc0ascnilz"
  }
]
```

## Columns

Columns represent stages in a workflow on a board. Cards move through columns as they progress.

### `GET /:account_slug/boards/:board_id/columns`

Returns a list of columns on a board, sorted by position.

__Response:__

```json
[
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohcm",
    "name": "Recording",
    "color": {
      "name": "Blue",
      "value": "var(--color-card-default)"
    },
    "created_at": "2025-12-05T19:36:35.534Z"
  },
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohcn",
    "name": "Published",
    "color": {
      "name": "Lime",
      "value": "var(--color-card-4)"
    },
    "created_at": "2025-12-05T19:36:35.534Z"
  }
]
```

### `GET /:account_slug/boards/:board_id/columns/:column_id`

Returns the specified column.

__Response:__

```json
{
  "id": "03f5v9zkft4hj9qq0lsn9ohcm",
  "name": "In Progress",
  "color": {
    "name": "Blue",
    "value": "var(--color-card-default)"
  },
  "created_at": "2025-12-05T19:36:35.534Z"
}
```

### `POST /:account_slug/boards/:board_id/columns`

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

### `PUT /:account_slug/boards/:board_id/columns/:column_id`

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

### `DELETE /:account_slug/boards/:board_id/columns/:column_id`

Deletes a column.

__Response:__

Returns `204 No Content` on success.

### `POST /:account_slug/columns/:column_id/left_position`

Moves a column one position to the left in the board's column order.

__Response:__

Returns `204 No Content` on success.

### `POST /:account_slug/columns/:column_id/right_position`

Moves a column one position to the right in the board's column order.

__Response:__

Returns `204 No Content` on success.

## Users

Users represent people who have access to an account.

### `GET /:account_slug/users`

Returns a list of active users in the account.

__Response:__

```json
[
  {
    "id": "03f5v9zjw7pz8717a4no1h8a7",
    "name": "David Heinemeier Hansson",
    "role": "owner",
    "active": true,
    "email_address": "david@example.com",
    "created_at": "2025-12-05T19:36:35.401Z",
    "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
  },
  {
    "id": "03f5v9zjysoy0fqs9yg0ei3hq",
    "name": "Jason Fried",
    "role": "member",
    "active": true,
    "email_address": "jason@example.com",
    "created_at": "2025-12-05T19:36:35.419Z",
    "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjysoy0fqs9yg0ei3hq"
  },
  {
    "id": "03f5v9zk1dtqduod5bkhv3k8m",
    "name": "Jason Zimdars",
    "role": "member",
    "active": true,
    "email_address": "jz@example.com",
    "created_at": "2025-12-05T19:36:35.435Z",
    "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zk1dtqduod5bkhv3k8m"
  },
  {
    "id": "03f5v9zk3nw9ja92e7s4h2wbe",
    "name": "Kevin Mcconnell",
    "role": "member",
    "active": true,
    "email_address": "kevin@example.com",
    "created_at": "2025-12-05T19:36:35.451Z",
    "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zk3nw9ja92e7s4h2wbe"
  }
]
```

### `GET /:account_slug/users/:user_id`

Returns the specified user.

__Response:__

```json
{
  "id": "03f5v9zjw7pz8717a4no1h8a7",
  "name": "David Heinemeier Hansson",
  "role": "owner",
  "active": true,
  "email_address": "david@example.com",
  "created_at": "2025-12-05T19:36:35.401Z",
  "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
}
```

### `PUT /:account_slug/users/:user_id`

Updates a user. You can only update users you have permission to change.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | No | The user's display name |
| `avatar` | file | No | The user's avatar image |

__Request:__

```json
{
  "user": {
    "name": "David H. Hansson"
  }
}
```

__Response:__

Returns `204 No Content` on success.

### `DELETE /:account_slug/users/:user_id`

Deactivates a user. You can only deactivate users you have permission to change.

__Response:__

Returns `204 No Content` on success.

### `PUT /:account_slug/users/:user_id/role`

Updates a user's role. Only account owners and admins can change user roles.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `role` | string | Yes | The new role: `admin` or `member` |

__Request:__

```json
{
  "user": {
    "role": "admin"
  }
}
```

__Response:__

Returns `204 No Content` on success.

## Notifications

Notifications inform users about events that happened in the account, such as comments, assignments, and card updates.

### `GET /:account_slug/notifications`

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

### `POST /:account_slug/notifications/:notification_id/reading`

Marks a notification as read.

__Response:__

Returns `204 No Content` on success.

### `DELETE /:account_slug/notifications/:notification_id/reading`

Marks a notification as unread.

__Response:__

Returns `204 No Content` on success.

### `POST /:account_slug/notifications/bulk_reading`

Marks all unread notifications as read.

__Response:__

Returns `204 No Content` on success.

## Account Settings

Account settings allow administrators to manage account-wide configuration.

### `GET /:account_slug/account/settings`

Returns the account settings. Only administrators can view account settings.

__Response:__

```json
{
  "id": "03f5v9zjskhcii2r45ih3u1rq",
  "name": "37signals"
}
```

### `PUT /:account_slug/account/settings`

Updates the account settings. Only administrators can update account settings.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | No | The account name |

__Request:__

```json
{
  "account": {
    "name": "New Account Name"
  }
}
```

__Response:__

Returns `204 No Content` on success.

### `PUT /:account_slug/account/entropy`

Updates the account-wide auto-postpone settings. This sets the default entropy period for all boards in the account.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `auto_postpone_period` | integer | Yes | Number of days of inactivity before cards are automatically postponed |

__Request:__

```json
{
  "entropy": {
    "auto_postpone_period": 30
  }
}
```

__Response:__

Returns `204 No Content` on success.

## Join Codes

Join codes allow new users to join an account without an explicit invitation.

### `GET /:account_slug/account/join_code`

Returns the account's join code configuration.

__Response:__

```json
{
  "code": "ABC123",
  "usage_limit": 50,
  "usage_count": 12
}
```

### `PUT /:account_slug/account/join_code`

Updates the join code configuration. Only administrators can update join code settings.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `usage_limit` | integer | No | Maximum number of times the join code can be used |

__Request:__

```json
{
  "account_join_code": {
    "usage_limit": 100
  }
}
```

__Response:__

Returns `204 No Content` on success.

### `DELETE /:account_slug/account/join_code`

Resets the join code. The existing code is invalidated and a new code is generated.

__Response:__

```json
{
  "code": "XYZ789",
  "usage_limit": 100,
  "usage_count": 0
}
```

## Exports

Exports allow users to download a complete archive of their account data.

### `GET /:account_slug/account/exports/:export_id`

Returns the status of an export.

__Response:__

```json
{
  "id": "03f5v9zo9qlcwwpyc0ascnikz",
  "status": "completed",
  "created_at": "2025-12-05T19:36:35.534Z"
}
```

### `POST /:account_slug/account/exports`

Starts a new export. The export will be built asynchronously and the user will be notified by email when it's ready for download.

__Response:__

Returns `202 Accepted` with the export details:

```json
{
  "id": "03f5v9zo9qlcwwpyc0ascnikz",
  "status": "pending",
  "created_at": "2025-12-05T19:36:35.534Z"
}
```

## Webhooks

Webhooks allow you to receive real-time notifications when events happen on a board.

### `GET /:account_slug/boards/:board_id/webhooks`

Returns a list of webhooks configured for the board. Only board administrators can view webhooks.

__Response:__

```json
[
  {
    "id": "03f5v9zo9qlcwwpyc0ascnikz",
    "name": "My Webhook",
    "url": "https://example.com/webhook",
    "subscribed_actions": ["card_closed", "card_reopened", "comment_created"],
    "created_at": "2025-12-05T19:36:35.534Z"
  }
]
```

### `GET /:account_slug/boards/:board_id/webhooks/:webhook_id`

Returns a specific webhook.

__Response:__

```json
{
  "id": "03f5v9zo9qlcwwpyc0ascnikz",
  "name": "My Webhook",
  "url": "https://example.com/webhook",
  "subscribed_actions": ["card_closed", "card_reopened", "comment_created"],
  "created_at": "2025-12-05T19:36:35.534Z",
  "updated_at": "2025-12-05T19:36:35.534Z"
}
```

### `POST /:account_slug/boards/:board_id/webhooks`

Creates a new webhook for the board. Only board administrators can create webhooks.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | A descriptive name for the webhook |
| `url` | string | Yes | The URL to receive webhook payloads |
| `subscribed_actions` | array | No | List of event types to subscribe to |

__Available actions:__

- `card_assigned` - A user was assigned to a card
- `card_closed` - A card was closed
- `card_postponed` - A card was manually moved to "Not Now"
- `card_auto_postponed` - A card was automatically postponed due to inactivity
- `card_board_changed` - A card was moved to a different board
- `card_published` - A drafted card was published
- `card_reopened` - A card was reopened
- `card_sent_back_to_triage` - A card was sent back to triage
- `card_triaged` - A card was moved to a column
- `card_unassigned` - A user was unassigned from a card
- `comment_created` - A comment was added

__Request:__

```json
{
  "webhook": {
    "name": "CI Integration",
    "url": "https://ci.example.com/fizzy/webhook",
    "subscribed_actions": ["card_closed", "comment_created"]
  }
}
```

__Response:__

Returns `201 Created` with the webhook details:

```json
{
  "id": "03f5v9zo9qlcwwpyc0ascnikz",
  "name": "CI Integration",
  "url": "https://ci.example.com/fizzy/webhook",
  "subscribed_actions": ["card_closed", "comment_created"],
  "created_at": "2025-12-05T19:36:35.534Z"
}
```

### `PUT /:account_slug/boards/:board_id/webhooks/:webhook_id`

Updates a webhook. The webhook URL cannot be changed after creation.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | No | A descriptive name for the webhook |
| `subscribed_actions` | array | No | List of event types to subscribe to |

__Request:__

```json
{
  "webhook": {
    "name": "Updated Webhook Name",
    "subscribed_actions": ["card_closed", "card_reopened", "comment_created"]
  }
}
```

__Response:__

Returns `204 No Content` on success.

### `DELETE /:account_slug/boards/:board_id/webhooks/:webhook_id`

Deletes a webhook.

__Response:__

Returns `204 No Content` on success.

### Webhook Payload Format

When an event occurs, Fizzy sends a POST request to your webhook URL with a JSON payload:

```json
{
  "id": "evt_03f5v9zo9qlcwwpyc0ascnikz",
  "action": "card_triaged",
  "created_at": "2025-12-05T19:36:35.534Z",
  "eventable": {
    "id": "03f5vaeq985jlvwv3arl4srq2",
    "number": 42,
    "title": "New feature request",
    "url": "http://fizzy.localhost:3006/897362094/cards/42"
  },
  "board": {
    "id": "03f5v9zkft4hj9qq0lsn9ohcm",
    "name": "Fizzy",
    "url": "http://fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm"
  },
  "creator": {
    "id": "03f5v9zjw7pz8717a4no1h8a7",
    "name": "David Heinemeier Hansson",
    "email_address": "david@example.com"
  }
}
```

Your endpoint should return a `2xx` status code to acknowledge receipt. Failed deliveries will be retried with exponential backoff.

---

## API Docs Maintenance

Use this checklist when the API changes:

### 1. Enumerate JSON endpoints

```bash
bin/rails routes > /tmp/fizzy_routes.txt
rg -n "format\.json|render json|head :|respond_to :json" app/controllers
rg -n "json.jbuilder" app/views  # find implicit JSON responses
```

### 2. Normalize paths before diff

Routes use `:id`/`:card_id`; docs use `:card_number`. Normalize placeholders before comparing. Docs use `/:account_slug` prefix (stripped by middleware). Some nested routes (e.g., column reordering) use `shallow: true`.

### 3. Validate request params

Confirm `params.expect/require` and any **top-level params** (e.g., `params[:user_ids]`). Update docs to match exact nesting (top-level vs `resource: { ... }`).

### 4. Validate responses

- `head :no_content` → **204 No Content**
- `head :created` + `location:` → **201 + Location header**
- `head :accepted` → **202 Accepted**
- Jbuilder view → verify fields in `app/views/**/*.json.jbuilder`

### 5. Errors

```bash
rg -n "unprocessable_entity|forbidden|unauthorized|too_many_requests" app/controllers
```

Add 401/403/422/429 notes to each affected endpoint.

### 6. Query parameters

For `/cards`, verify `Filter::Params::PERMITTED_PARAMS` and document all `terms[]`, `indexed_by`, `sorted_by`, etc.

### 7. Webhook actions

Verify against `Webhook::PERMITTED_ACTIONS` (`app/models/webhook.rb`). Update both docs and CLI help (`cli/lib/commands/webhooks.sh`).

### 8. CLI alignment

Ensure CLI help/examples match docs (params, nesting, status codes).

### 9. Regression check

```bash
bin/rails test test/controllers/**/*_test.rb
bats cli/test/*.bats
```
