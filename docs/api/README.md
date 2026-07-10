# Fizzy API

Fizzy has an API that allows you to integrate your application with it or to create
a bot to perform various actions for you.

## API Endpoints

- [Authentication](sections/authentication.md)
- [Identity](sections/identity.md)
- [Account](sections/account.md)
- [Boards](sections/boards.md)
- [Columns](sections/columns.md)
- [Cards](sections/cards.md)
- [Pins](sections/pins.md)
- [Steps](sections/steps.md)
- [Comments](sections/comments.md)
- [Reactions](sections/reactions.md)
- [Tags](sections/tags.md)
- [Users](sections/users.md)
- [Activities](sections/activities.md)
- [Notifications](sections/notifications.md)
- [Rich Text](sections/rich_text.md)
- [Exports](sections/exports.md)
- [Webhooks](sections/webhooks.md)

## Authentication

There are two ways to authenticate with the Fizzy API:

1. **Personal access tokens** - Long-lived tokens for scripts and integrations
2. **Magic link authentication** - Session-based authentication for native apps

Read the [authentication guide](sections/authentication.md) to get started.

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
| `422 Unprocessable Entity` | Validation failed (see error response format above) |
| `500 Internal Server Error` | An unexpected error occurred on the server |

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
curl -H "Authorization: Bearer put-your-access-token-here" -H "Accept: application/json" -v http://app.fizzy.localhost:3006/686465299/cards
# ...
< link: <http://app.fizzy.localhost:3006/686465299/cards?page=2>; rel="next"
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
  http://app.fizzy.localhost:3006/686465299/users/03f5v9zjw7pz8717a4no1h8a7
```

## Rich Text Fields

Some fields accept rich text content. These fields accept HTML input, which will be sanitized to remove unsafe tags and attributes.

See the [rich text guide](sections/rich_text.md) for more information, including how to attach files to rich text fields using the direct upload flow.


