# API ↔ CLI Parity Matrix

Status: ✅ full | ⚠️ partial | — not covered

| Area | API Docs | CLI Commands | Notes |
|------|----------|--------------|-------|
| Auth | ✅ PAT + magic link | ✅ PAT (`FIZZY_TOKEN`) | OAuth undocumented |
| Identity | ✅ `GET /my/identity` | ✅ `fizzy identity` | |
| Boards | ✅ list/show/create/update/delete | ✅ `boards`, `board show/create/update/delete` | |
| Board publish | ✅ publish/unpublish | ✅ `board publish/unpublish` | Uses publish response URL |
| Board entropy | ✅ | ✅ `board entropy` | |
| Columns | ✅ list/show/create/update/delete | ✅ `columns`, `column show/create/update/delete` | |
| Column reorder | ✅ left/right | ✅ `column left/right` | Shallow routes (no board in path) |
| Cards list/show | ✅ filters + show | ✅ `cards`, `show` | Search via `terms[]` filter |
| Card create/update/delete | ✅ | ✅ `card`, `card update`, `card delete` | |
| Card image | ✅ delete | ✅ `card image delete` | |
| Card lifecycle | ✅ close/reopen/postpone | ✅ `close`, `reopen`, `postpone` | |
| Card triage | ✅ triage/untriage | ✅ `triage`, `untriage` | |
| Card tagging | ✅ | ✅ `tag`, `untag` | |
| Card assignment | ✅ | ✅ `assign`, `unassign` | |
| Card watch | ✅ | ✅ `watch`, `unwatch` | |
| Card gold | ✅ | ✅ `gild`, `ungild` | |
| Card publish | ✅ | ✅ `card publish` | |
| Card move | ✅ | ✅ `card move --to` | Top-level `board_id` |
| Comments | ✅ list/show/create/update/delete | ✅ `comments`, `comment`, `comment edit/delete` | Update returns 204 |
| Reactions | ✅ list/create/delete | ✅ `reactions`, `react`, `react delete` | |
| Steps | ✅ show/create/update/delete | ✅ `step show/create/update/delete` | |
| Tags | ✅ list | ✅ `tags` | |
| Users | ✅ list/show/update/delete/role | ✅ `people`, `user show/update/delete/role` | |
| Notifications | ✅ list/read/unread/bulk | ✅ `notifications`, `read/unread/read-all` | |
| Account | ✅ show/update/entropy/join-code/export | ✅ `account show/update/entropy/join-code/export` | Export accepts 202 |
| Webhooks | ✅ list/show/create/update/delete | ✅ `webhooks`, `webhook create/show/update/delete` | Actions match `PERMITTED_ACTIONS` |

## Intentional Omissions

These API endpoints exist but are intentionally not documented or exposed in the CLI:

| Endpoint | Reason |
|----------|--------|
| `POST/DELETE /cards/:card_id/pin` | Internal UI feature |
| `PUT /boards/:board_id/involvement` | Internal UI feature |

These are Tier 3 endpoints—functional but not part of the public API contract.
