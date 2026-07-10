# Rich Text Fields

Some fields accept rich text content. These fields accept HTML input, which will be sanitized to remove unsafe tags and attributes.

```json
{
  "card": {
    "title": "My card",
    "description": "<p>This is <strong>bold</strong> and this is <em>italic</em>.</p><ul><li>Item 1</li><li>Item 2</li></ul>"
  }
}
```

## Attaching files to rich text

To attach files (images, documents) to rich text fields, use ActionText's direct upload flow:

### 1. Create a direct upload

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

### 2. Upload the file

Upload the file directly to the provided URL with the specified headers:

```bash
curl -X PUT \
  -H "Content-Type: image/png" \
  -H "Content-MD5: GQ5SqLsM7ylnji0Wgd9wNA==" \
  --data-binary @screenshot.png \
  "https://storage.example.com/..."
```

### 3. Reference the file in rich text

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
