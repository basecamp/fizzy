# Events API Test Results

**Date:** 2025-12-25
**Endpoint:** `GET /:account_slug/events`
**Account:** `/897362094` (37signals)

## Credentials

```bash
TOKEN="GrFp8sJNFU2TLt6phAz3FKcL"
BASE="http://fizzy.localhost:3006/897362094"
```

## Test Results

| Filter          | Status  | Notes                                     |
|-----------------|---------|-------------------------------------------|
| `card_ids[]`    | Works   | Correctly filters to specific card(s)     |
| `since`         | Works   | Correctly filters events after timestamp  |
| `until`         | Works   | Correctly filters events before timestamp |
| `board_ids[]`   | Partial | Filters correctly, but 500s on invalid ID |
| `creator_ids[]` | Partial | Filters correctly, but 500s on invalid ID |
| `action`        | Broken  | Completely ignored, returns all events    |
| `actions[]`     | Broken  | Completely ignored, returns all events    |

## Bug Details

### 1. `action` and `actions[]` filters are ignored

The action filters don't filter at all. They return all events regardless of the value.

**Reproduction:**

```bash
# Should return 1 event (only card_closed), but returns 8 (all events)
curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" \
  "$BASE/events?action=card_closed" | jq 'length'
# Returns: 8

# Should return 3 events (assigned + closed), but returns 8
curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" \
  "$BASE/events?actions[]=card_assigned&actions[]=card_closed" | jq 'length'
# Returns: 8

# Even nonexistent action returns all events
curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" \
  "$BASE/events?action=nonexistent" | jq 'length'
# Returns: 8
```

**Expected:** Filter should only return events matching the specified action type(s).

**Actual:** Filter is ignored, all events are returned.

### 2. Invalid IDs cause 500 errors

When `board_ids[]` or `creator_ids[]` contain invalid IDs, the API returns a 500 error instead of a 404 or empty array.

**Reproduction:**

```bash
# Returns 500 with "Couldn't find Board with 'id'="nonexistent""
curl -s -w "\nHTTP: %{http_code}" \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" \
  "$BASE/events?board_ids[]=nonexistent"

# Returns 500 with "Couldn't find User with 'id'="nonexistent""
curl -s -w "\nHTTP: %{http_code}" \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" \
  "$BASE/events?creator_ids[]=nonexistent"
```

**Expected:** Return 404 or empty array `[]` for invalid IDs.

**Actual:** Returns 500 Internal Server Error with `ActiveRecord::RecordNotFound`.

## Working Examples

```bash
# Filter by card ID - works
curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" \
  "$BASE/events?card_ids[]=03f5d9lyufqnat3nrof1btvlu" | jq 'length'
# Returns: 3

# Filter by since - works
curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" \
  "$BASE/events?since=2025-12-03T12:30:00Z" | jq 'length'
# Returns: 2

# Filter by until - works
curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" \
  "$BASE/events?until=2025-12-03T12:20:00Z" | jq 'length'
# Returns: 6
```

## Event Counts in Test Data

```
card_assigned: 2
card_closed: 1
card_published: 3
card_sent_back_to_triage: 1
card_triaged: 1
Total: 8
```
