# Exports

Exports are asynchronous jobs. Start an export with `POST`, then poll the export resource with `GET` until it reaches `completed`. When the export file is ready, the response includes a temporary `download_url`.

Possible export statuses are:
- `pending`
- `processing`
- `completed`
- `failed`

Completed export files expire after 24 hours. When that happens, request a new export.

## `POST /account/exports`

Starts an account export for the current account. Only account admins and owners can create account exports.

__Response:__

Returns `201 Created` with the export object:

```json
{
  "id": "03f8huu0sog76g3s97596abcd",
  "status": "pending",
  "created_at": "2026-04-02T12:34:56Z"
}
```

## `GET /account/exports/:id`

Returns the status of an account export created by the current user.

__Response:__

```json
{
  "id": "03f8huu0sog76g3s97596abcd",
  "status": "completed",
  "created_at": "2026-04-02T12:34:56Z",
  "download_url": "https://app.fizzy.do/rails/active_storage/blobs/redirect/.../fizzy-account-export.zip"
}
```

The `download_url` field is only present when the export is completed and the export file is still available. Download requests still require normal authenticated access as the export owner.

## `POST /:account_slug/users/:user_id/data_exports`

Starts a personal data export for the current user. You can only create exports for your own user record.

__Response:__

Returns `201 Created` with the export object:

```json
{
  "id": "03f8huu0sog76g3s97596wxyz",
  "status": "pending",
  "created_at": "2026-04-02T12:34:56Z"
}
```

## `GET /:account_slug/users/:user_id/data_exports/:id`

Returns the status of one of your personal data exports.

__Response:__

```json
{
  "id": "03f8huu0sog76g3s97596wxyz",
  "status": "completed",
  "created_at": "2026-04-02T12:34:56Z",
  "download_url": "https://app.fizzy.do/rails/active_storage/blobs/redirect/.../fizzy-user-data-export.zip"
}
```

The `download_url` field is only present when the export is completed and the export file is still available. Download requests still require normal authenticated access as the export owner.
