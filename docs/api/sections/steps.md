# Steps

Steps are to-do items on a card.

## `GET /:account_slug/cards/:card_number/steps/:step_id`

Returns a specific step.

__Response:__

```json
{
  "id": "03f5v9zo9qlcwwpyc0ascnikz",
  "content": "Write tests",
  "completed": false
}
```

## `POST /:account_slug/cards/:card_number/steps`

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

## `PUT /:account_slug/cards/:card_number/steps/:step_id`

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

## `DELETE /:account_slug/cards/:card_number/steps/:step_id`

Deletes a step.

__Response:__

Returns `204 No Content` on success.
