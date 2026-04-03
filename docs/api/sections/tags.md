# Tags

Tags are labels that can be applied to cards for organization and filtering.

## `GET /:account_slug/tags`

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
