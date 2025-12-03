# UserPromptSubmit API

Available when inheriting from `ClaudeHooks::UserPromptSubmit`:

## Input Helpers
Input helpers to access the data provided by Claude Code through `STDIN`.

[📚 Shared input helpers](COMMON.md#input-helpers)

| Method           | Description                |
|------------------|----------------------------|
| `prompt`         | Get the user's prompt text |
| `user_prompt`    | Alias for `prompt`         |
| `current_prompt` | Alias for `prompt`         |

## Hook State Helpers
Hook state methods are helpers to modify the hook's internal state (`output_data`) before yielding back to Claude Code.

[📚 Shared hook state methods](COMMON.md#hook-state-methods)

| Method                             | Description                         |
|------------------------------------|-------------------------------------|
| `add_additional_context!(context)` | Add context to the prompt           |
| `add_context!(context)`            | Alias for `add_additional_context!` |
| `empty_additional_context!`        | Remove additional context           |
| `block_prompt!(reason)`            | Block the prompt from processing    |
| `unblock_prompt!`                  | Unblock a previously blocked prompt |

## Output Helpers
Output helpers provide access to the hook's output data and helper methods for working with the output state.

[📚 Shared output helpers](COMMON.md#output-helpers)

| Method                      | Description                                                |
|-----------------------------|------------------------------------------------------------|
| `output.decision`           | Get the decision: "block" or nil (default)                 |
| `output.reason`             | Get the reason for the decision                            |
| `output.blocked?`           | Check if the prompt has been blocked (decision == 'block') |
| `output.additional_context` | Get the additional context that was added                  |

## Hook Exit Codes

| Exit Code | Behavior                                                                           |
|-----------|------------------------------------------------------------------------------------|
| `exit 0`  | Operation continues<br/>**`STDOUT` added as context to Claude**                    |
| `exit 1`  | Non-blocking error<br/>`STDERR` shown to user                                      |
| `exit 2`  | **Blocks prompt processing**<br/>**Erases prompt**<br/>`STDERR` shown to user only |
