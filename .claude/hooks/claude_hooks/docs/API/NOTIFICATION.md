# Notification API

Available when inheriting from `ClaudeHooks::Notification`:

## Input Helpers
Input helpers to access the data provided by Claude Code through `STDIN`.

[📚 Shared input helpers](COMMON.md#input-helpers)

| Method                 | Description                          |
|------------------------|--------------------------------------|
| `message`              | Get the notification message content |
| `notification_message` | Alias for `message`                  |

## Hook State Helpers
Notifications are outside facing and do not have any specific state to modify.

[📚 Shared hook state methods](COMMON.md#hook-state-methods)

## Output Helpers
Output helpers provide access to the hook's output data and helper methods for working with the output state.
Notifications don't have any specific hook state and thus doesn't have any specific output helpers.

[📚 Shared output helpers](COMMON.md#output-helpers)

## Hook Exit Codes

| Exit Code | Behavior                                                 |
|-----------|----------------------------------------------------------|
| `exit 0`  | Operation continues<br/>Logged to debug only (`--debug`) |
| `exit 1`  | Non-blocking error<br/>Logged to debug only (`--debug`)  |
| `exit 2`  | N/A<br/>Logged to debug only (`--debug`)                 |
