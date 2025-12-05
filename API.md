# Fizzy REST API

This document describes the REST API for Fizzy, which allows external applications to interact with boards, cards, and comments programmatically.

## Authentication

All API requests must include an API token in the `Authorization` header:

```
Authorization: Bearer YOUR_API_TOKEN
```

API tokens can be created and managed through the admin interface at `/admin/api_tokens`.

## Base URL

The API base URL is `/api`. All endpoints are prefixed with this path.

## Endpoints

### Boards

#### List Boards
```
GET /api/boards
```

Returns a list of all boards accessible to the authenticated user.

**Response:**
```json
[
  {
    "id": "03f5swdbgdw56ecg7hjgowotc",
    "name": "Test Board",
    "all_access": true,
    "created_at": "2025-12-05T12:18:18Z",
    "updated_at": "2025-12-05T12:18:20Z",
    "creator": {
      "id": "03f5rbdwmg3sx2tntbr587rng",
      "name": "David Heinemeier Hansson"
    }
  }
]
```

#### Get Board
```
GET /api/boards/:id
```

Returns details for a specific board.

**Response:**
```json
{
  "id": "03f5swdbgdw56ecg7hjgowotc",
  "name": "Test Board",
  "all_access": true,
  "created_at": "2025-12-05T12:18:18Z",
  "updated_at": "2025-12-05T12:18:20Z",
  "creator": {
    "id": "03f5rbdwmg3sx2tntbr587rng",
    "name": "David Heinemeier Hansson"
  }
}
```

### Cards

#### Create Card
```
POST /api/boards/:board_id/cards
```

Creates a new card in the specified board.

**Request Body:**
```json
{
  "title": "My Card Title",
  "description": "Card description",
  "column": "In Progress",
  "tags": ["urgent", "bug"]
}
```

**Response:**
```json
{
  "id": 1,
  "title": "My Card Title",
  "description": "Card description",
  "status": "published",
  "column": "In Progress",
  "board_id": "03f5swdbgdw56ecg7hjgowotc",
  "tags": ["urgent", "bug"],
  "assignees": [],
  "created_at": "2025-12-05T12:18:27Z",
  "updated_at": "2025-12-05T12:18:27Z"
}
```

#### Move Card
```
POST /api/cards/:card_id/move
```

Moves a card to a different column.

**Request Body:**
```json
{
  "to_column": "Done"
}
```

**Response:**
```json
{
  "id": 1,
  "title": "My Card Title",
  "description": "Card description",
  "status": "published",
  "column": "Done",
  "board_id": "03f5swdbgdw56ecg7hjgowotc",
  "tags": ["urgent", "bug"],
  "assignees": [],
  "created_at": "2025-12-05T12:18:27Z",
  "updated_at": "2025-12-05T12:19:31Z"
}
```

#### Close Card
```
POST /api/cards/:card_id/close
```

Closes a card (moves it to "Done").

**Response:**
```json
{
  "id": 1,
  "title": "My Card Title",
  "status": "published",
  "column": null,
  ...
}
```

#### Reopen Card
```
POST /api/cards/:card_id/reopen
```

Reopens a closed card.

**Response:**
```json
{
  "id": 1,
  "title": "My Card Title",
  "status": "published",
  ...
}
```

#### Assign Card
```
POST /api/cards/:card_id/assign
```

Assigns or unassigns a user to/from a card.

**Request Body:**
```json
{
  "user_id": "03f5rbdwmg3sx2tntbr587rng"
}
```

**Response:**
```json
{
  "id": 1,
  "title": "My Card Title",
  "assignees": [
    {
      "id": "03f5rbdwmg3sx2tntbr587rng",
      "name": "David Heinemeier Hansson"
    }
  ],
  ...
}
```

#### Tag Card
```
POST /api/cards/:card_id/tag
```

Adds or removes tags from a card.

**Request Body:**
```json
{
  "tags": ["urgent", "bug", "frontend"]
}
```

**Response:**
```json
{
  "id": 1,
  "title": "My Card Title",
  "tags": ["urgent", "bug", "frontend"],
  ...
}
```

### Comments

#### Create Comment
```
POST /api/cards/:card_id/comments
```

Creates a comment on a card.

**Request Body:**
```json
{
  "body": "This is a comment"
}
```

**Response:**
```json
{
  "id": "03f5swkrqzw24bx0ob1wtewpa",
  "body": "This is a comment",
  "card_id": 1,
  "creator": {
    "id": "03f5rbdwljhrmbqpk1erhobzo",
    "name": "System"
  },
  "created_at": "2025-12-05T12:19:21Z"
}
```

## Error Responses

All endpoints return standard HTTP status codes. Error responses follow this format:

```json
{
  "error": "error_type",
  "message": "Human-readable error message"
}
```

### Common Error Types

- `not_found` (404): Resource not found
- `validation_error` (422): Validation failed
- `bad_request` (400): Invalid request parameters
- `unauthorized` (401): Missing or invalid API token

## Managing API Tokens and Board Access

### Creating API Tokens

API tokens can be created through the admin interface or programmatically:

```ruby
ApiToken.create!(
  account: account,
  name: "My API Token"
)
```

### Granting Board Access to API Tokens

By default, API tokens are associated with the account's system user. To grant access to specific boards, you can use the provided scripts:

**Simple script for a single token:**
```bash
docker-compose exec app bin/rails runner script/grant_board_access_simple.rb
```

**Script for specific boards:**
```bash
docker-compose exec app bin/rails runner script/grant_access_to_specific_boards.rb
```

**Full script for multiple tokens:**
```bash
docker-compose exec app bin/rails runner script/grant_board_access_to_api_tokens.rb
```

Or programmatically via Rails console:

```ruby
token = ApiToken.find_by(token: "YOUR_TOKEN")
user = token.user
board = Board.find("BOARD_ID")

# Method 1: Via board.accesses.grant_to (recommended)
board.accesses.grant_to([user])

# Method 2: Via Access.create directly
Access.create!(
  user: user,
  board: board,
  account: token.account,
  involvement: :access_only
)
```

**Note:** Boards with `all_access: true` automatically grant access to all active users in the account, so explicit access records are not needed for those boards.

## Examples

### Using curl

```bash
# List boards
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://fizzy.localhost:3006/api/boards

# Create a card
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"New Card","description":"Card description"}' \
  http://fizzy.localhost:3006/api/boards/BOARD_ID/cards

# Add a comment
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"body":"This is a comment"}' \
  http://fizzy.localhost:3006/api/cards/CARD_ID/comments
```

