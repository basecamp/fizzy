# SessionEnd API

> [!NOTE] 
> SessionEnd hooks cannot block session termination - they are designed for cleanup tasks only.

Available when inheriting from `ClaudeHooks::SessionEnd`:

## Input Helpers
Input helpers to access the data provided by Claude Code through `STDIN`.

[📚 Shared input helpers](COMMON.md#input-helpers)

| Method   | Description                            |
|----------|----------------------------------------|
| `reason` | Get the reason for session termination |

### Reason Helpers

| Method               | Description                                         |
|----------------------|-----------------------------------------------------|
| `cleared?`           | Check if session was cleared with `/clear` command  |
| `logout?`            | Check if user logged out                            |
| `prompt_input_exit?` | Check if user exited while prompt input was visible |
| `other_reason?`      | Check if reason is unspecified or other             |

## Hook State Helpers
Hook state methods are helpers to modify the hook's internal state (`output_data`) before yielding back to Claude Code.
SessionEnd hooks do not have any specific state to modify.

[📚 Shared hook state methods](COMMON.md#hook-state-methods)

## Output Helpers
Output helpers provide access to the hook's output data and helper methods for working with the output state.
SessionEnd hooks don't have any specific hook state and thus doesn't have any specific output helpers.

[📚 Shared output helpers](COMMON.md#output-helpers)

## Hook Exit Codes

| Exit Code | Behavior                                                 |
|-----------|----------------------------------------------------------|
| `exit 0`  | Operation continues<br/>Logged to debug only (`--debug`) |
| `exit 1`  | Non-blocking error<br/>Logged to debug only (`--debug`)  |
| `exit 2`  | N/A<br/>Logged to debug only (`--debug`)                 |

## Example Usage

```ruby
#!/usr/bin/env ruby

require 'claude_hooks'

class MySessionCleanup < ClaudeHooks::SessionEnd
  def call
    log "Session ending with reason: #{reason}"
    
    if cleared?
      log "Cleaning up after /clear command"
      add_cleanup_message!("Temporary files cleaned")
    elsif logout?
      log "User logged out - saving state"
      log_session_info!("Session saved successfully")
    elsif prompt_input_exit?
      log "Interrupted during prompt - partial cleanup"
      add_cleanup_message!("Partial state saved")
    else
      log "General session cleanup"
      add_cleanup_message!("Session ended normally")
    end
    
    output
  end
end

# CLI testing
if __FILE__ == $0
  ClaudeHooks::CLI.test_runner(MySessionCleanup)
end
```

## Session Configuration

Register the hook in your `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/entrypoints/session_end.rb"
          }
        ]
      }
    ]
  }
}
```
