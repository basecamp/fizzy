# PreToolUse API

Available when inheriting from `ClaudeHooks::PreToolUse`:

## Input Helpers
Input helpers to access the data provided by Claude Code through `STDIN`.

[📚 Shared input helpers](COMMON.md#input-helpers)

| Method       | Description                         |
|--------------|-------------------------------------|
| `tool_name`  | Get the name of the tool being used |
| `tool_input` | Get the input data for the tool     |

## Hook State Helpers
Hook state methods are helpers to modify the hook's internal state (`output_data`) before yielding back to Claude Code.

[📚 Shared hook state methods](COMMON.md#hook-state-methods)

| Method                        | Description                    |
|-------------------------------|--------------------------------|
| `approve_tool!(reason)`       | Explicitly approve tool usage  |
| `block_tool!(reason)`         | Block tool usage with feedback |
| `ask_for_permission!(reason)` | Request user permission        |

## Output Helpers
Output helpers provide access to the hook's output data and helper methods for working with the output state.

[📚 Shared output helpers](COMMON.md#output-helpers)

| Method                          | Description                                                                    |
|---------------------------------|--------------------------------------------------------------------------------|
| `output.allowed?`               | Check if the tool has been explicitly allowed (permission_decision == 'allow') |
| `output.denied?`                | Check if the tool has been denied (permission_decision == 'deny')              |
| `output.blocked?`               | Alias for `denied?`                                                            |
| `output.should_ask_permission?` | Check if user permission is required (permission_decision == 'ask')            |
| `output.permission_decision`    | Get the permission decision: 'allow', 'deny', or 'ask'                         |
| `output.permission_reason`      | Get the reason for the permission decision                                     |

## Hook Exit Codes

| Exit Code | Behavior                                                          |
|-----------|-------------------------------------------------------------------|
| `exit 0`  | Operation continues<br/>`STDOUT` shown to user in transcript mode |
| `exit 1`  | Non-blocking error<br/>`STDERR` shown to user                     |
| `exit 2`  | **Blocks the tool call**<br/>`STDERR` shown to Claude             |

## Exit code behaviors related to chosen output stream
Outputting to a specific stream has a different effect depending on the exit code.

> [!TIP]
> The most common and useful cases expressed in the tables below are handled automatically by calling `hook.output_and_exit`. 
> You only need to worry about this when you want very specific behavior.

### ALLOW

#### Claude Code behavior depending on combination

| Exit Code  | STDERR | STDOUT |
|------------|--------|--------|
| 0          | RUNS   | RUNS   |
| 1          | RUNS   | RUNS   |
| 2          | BLOCKS | RUNS   |

#### Output visibility depending on exit code

| Output Visibility / Exit Code | 0     | 1     | 2     |
|-------------------------------|-------|-------|-------|
| **STDOUT sent to Claude**     | ✅ YES | ✅ YES | ✅ YES |
| **STDOUT shown to User**      | ❌ NO  | ❌ NO  | ❌ NO  |
| **STDERR sent to Claude**     | ❌ NO  | ❌ NO  | ✅ YES |
| **STDERR shown to User**      | ❌ NO  | ✅ YES | ✅ YES |

### ASK

#### Claude Code behavior depending on combination

| Exit Code  | STDERR | STDOUT |
|------------|--------|--------|
| 0          | RUNS   | ASKS   |
| 1          | RUNS   | ASKS   |
| 2          | BLOCKS | ASKS   |

#### Output visibility depending on exit code

| Output Visibility / Exit Code | 0     | 1     | 2     |
|-------------------------------|-------|-------|-------|
| **STDOUT sent to Claude**     | ✅ YES | ✅ YES | ✅ YES |
| **STDOUT shown to User**      | ✅ YES | ✅ YES | ✅ YES |
| **STDERR sent to Claude**     | ❌ NO  | ❌ NO  | ✅ YES |
| **STDERR shown to User**      | ❌ NO  | ✅ YES | ✅ YES |

### DENY

#### Claude Code behavior depending on combination

| Exit Code  | STDERR | STDOUT |
|------------|--------|--------|
| 0          | BLOCKS | BLOCKS |
| 1          | BLOCKS | BLOCKS |
| 2          | BLOCKS | BLOCKS |

#### Output visibility depending on exit code

| Output Visibility / Exit Code | 0     | 1     | 2     |
|-------------------------------|-------|-------|-------|
| **STDOUT sent to Claude**     | ✅ YES | ✅ YES | ✅ YES |
| **STDOUT shown to User**      | ✅ YES | ✅ YES | ✅ YES |
| **STDERR sent to Claude**     | ❌ NO  | ❌ NO  | ✅ YES |
| **STDERR shown to User**      | ❌ NO  | ✅ YES | ✅ YES |
