# SubagentStop API

Available when inheriting from `ClaudeHooks::SubagentStop` (inherits from `ClaudeHooks::Stop`):

## Input Helpers
Input helpers to access the data provided by Claude Code through `STDIN`.

[📚 Shared input helpers](COMMON.md#input-helpers)

| Method             | Description                                                           |
|--------------------|-----------------------------------------------------------------------|
| `stop_hook_active` | Check if Claude Code is already continuing as a result of a stop hook |

## Hook State Helpers
Hook state methods are helpers to modify the hook's internal state (`output_data`) before yielding back to Claude Code.

[📚 Shared hook state methods](COMMON.md#hook-state-methods)

> [!NOTE] 
> In Stop hooks, the decision to "block" actually means to "force Claude to continue", we are "blocking" the blockage. 
> This is counterintuitive and the reason why the method `block!` is aliased to `continue_with_instructions!`

| Method                                      | Description                                                     |
|---------------------------------------------|-----------------------------------------------------------------|
| `continue_with_instructions!(instructions)` | Block Claude from stopping and provide instructions to continue |
| `block!(instructions)`                      | Alias for `continue_with_instructions!`                         |
| `ensure_stopping!`                          | Allow Claude to stop normally (default behavior)                |

## Output Helpers
Output helpers provide access to the hook's output data and helper methods for working with the output state.

[📚 Shared output helpers](COMMON.md#output-helpers)

| Method                         | Description                                                        |
|--------------------------------|--------------------------------------------------------------------|
| `output.should_continue?`      | Check if Claude should be forced to continue (decision == 'block') |
| `output.should_stop?`          | Check if Claude should stop normally (decision != 'block')         |
| `output.continue_instructions` | Get the continue instructions (alias for `reason`)                 |
| `output.reason`                | Get the reason for the decision                                    |

## Hook Exit Codes

| Exit Code | Behavior                                                         |
|-----------|------------------------------------------------------------------|
| `exit 0`  | Subagent will stop<br/>`STDOUT` shown to user in transcript mode |
| `exit 1`  | Non-blocking error<br/>`STDERR` shown to user                    |
| `exit 2`  | **Blocks stoppage**<br/>`STDERR` shown to Claude subagent        |
