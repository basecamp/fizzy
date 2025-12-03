# SessionStart API

Available when inheriting from `ClaudeHooks::SessionStart`:

## Input Helpers
Input helpers to access the data provided by Claude Code through `STDIN`.

[📚 Shared input helpers](COMMON.md#input-helpers)

| Method   | Description                                                         |
|----------|---------------------------------------------------------------------|
| `source` | Get the session start source: `'startup'`, `'resume'`, or `'clear'` |

## Hook State Helpers
Hook state methods are helpers to modify the hook's internal state (`output_data`) before yielding back to Claude Code.

[📚 Shared hook state methods](COMMON.md#hook-state-methods)

| Method                             | Description                                     |
|------------------------------------|-------------------------------------------------|
| `add_additional_context!(context)` | Add contextual information for Claude's session |
| `add_context!(context)`            | Alias for `add_additional_context!`             |
| `empty_additional_context!`        | Clear additional context                        |

## Output Helpers
Output helpers provide access to the hook's output data and helper methods for working with the output state.

[📚 Shared output helpers](COMMON.md#output-helpers)

| Method                      | Description                               |
|-----------------------------|-------------------------------------------|
| `output.additional_context` | Get the additional context that was added |

## Hook Exit Codes

| Exit Code | Behavior                                                        |
|-----------|-----------------------------------------------------------------|
| `exit 0`  | Operation continues<br/>**`STDOUT` added as context to Claude** |
| `exit 1`  | Non-blocking error<br/>`STDERR` shown to user                   |
| `exit 2`  | N/A<br/>`STDERR` shown to user only                             |
