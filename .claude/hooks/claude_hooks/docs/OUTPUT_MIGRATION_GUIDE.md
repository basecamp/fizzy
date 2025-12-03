# Migration Guide: Using Output Objects

This guide shows how to migrate from the old manual exit code patterns to the new simplified output object system.

## Problem: The Old Way (Before)

```ruby
#!/usr/bin/env ruby

require 'claude_hooks'
require_relative '../handlers/pre_tool_use/github_guard'

begin
  # Read Claude Code input from stdin
  input_data = JSON.parse(STDIN.read)

  github_guard = GithubGuard.new(input_data)
  guard_output = github_guard.call

  # MANUAL: Extract hook-specific decision
  hook_specific_decision = guard_output['hookSpecificOutput']['permissionDecision']
  is_allowed_to_continue = guard_output['continue'] != false
  final_output = github_guard.stringify_output

  # MANUAL: Complex exit logic that you need to understand and get right
  if is_allowed_to_continue
    case hook_specific_decision
    when 'block'
      STDERR.puts final_output
      exit 1
    when 'ask'
      STDERR.puts final_output
      exit 2
    else
      puts final_output
      exit 0
    end
  else
    STDERR.puts final_output
    exit 1
  end
rescue StandardError => e
  # MANUAL: Error handling with manual JSON generation and stream selection
  puts JSON.generate({
    continue: false,
    stopReason: "PreToolUser Hook execution error: #{e.message}",
    suppressOutput: false
  })
  exit 0 # Allow anyway to not block developers if there is an issue
end
```

**Problems with this approach:**
- 30+ lines of repetitive boilerplate
- Need to understand Claude Code's internal exit code semantics
- Manual stream selection (STDOUT vs STDERR)
- Error-prone - easy to get exit codes wrong
- Need to manually extract hook-specific data from nested hashes

## Solution: The New Way (After)

```ruby
#!/usr/bin/env ruby

require 'claude_hooks'
require_relative '../handlers/pre_tool_use/github_guard'

begin
  # Read Claude Code input from stdin
  input_data = JSON.parse(STDIN.read)

  github_guard = GithubGuard.new(input_data)
  github_guard.call

  # NEW: One line handles everything!
  github_guard.output_and_exit

rescue StandardError => e
  # NEW: Simple error handling
  error_output = ClaudeHooks::Output::PreToolUse.new({
    'continue' => false,
    'stopReason' => "Hook execution error: #{e.message}",
    'suppressOutput' => false
  })
  error_output.output_and_exit  # Automatically uses STDERR and exit 1
end
```

**Benefits:**
- **10 lines instead of 30+** - 70% less code
- **No Claude Code knowledge needed** - just use the gem's API
- **Automatic exit codes** based on hook-specific logic
- **Automatic stream selection** (STDOUT/STDERR)
- **Type-safe access** to hook-specific fields

## New Output Object API

### PreToolUse Hooks

```ruby
hook = GithubGuard.new(input_data)
hook.call
output = hook.output

# Clean semantic access
puts "Permission: #{output.permission_decision}"  # 'allow', 'deny', or 'ask'
puts "Reason: #{output.permission_reason}"
puts "Allowed? #{output.allowed?}"
puts "Should ask? #{output.should_ask_permission?}"

# Automatic exit logic
puts "Exit code: #{output.exit_code}"      # 0, 1, or 2 based on permission
puts "Stream: #{output.output_stream}"     # :stdout or :stderr

# One call handles everything
hook.output_and_exit  # Prints JSON to correct stream and exits with correct code
```

### UserPromptSubmit Hooks

```ruby
hook = MyPromptHook.new(input_data)
hook.call
output = hook.output

# Clean semantic access
puts "Blocked? #{output.blocked?}"
puts "Reason: #{output.reason}"
puts "Context: #{output.additional_context}"

# Automatic execution
hook.output_and_exit # Handles all the exit logic
```

### Stop Hooks (Special Logic)

```ruby
hook = MyStopHook.new(input_data)
hook.call
output = hook.output

# Note: Stop hooks have inverted logic - 'decision: block' means "continue working"
puts "Should continue? #{output.should_continue?}"      # true if decision == 'block'
puts "Continue instructions: #{output.continue_instructions}"

hook.output_and_exit  # exit 1 for "continue", exit 0 for "stop"
```

## Merging Multiple Hooks

```ruby
# OLD WAY: Manual merging with class methods
result1 = hook1.call
result2 = hook2.call
merged_hash = ClaudeHooks::PreToolUse.merge_outputs(result1, result2)
# ... then manual exit logic

# NEW WAY: Clean object-based merging
hook1.call
hook2.call
merged_output = ClaudeHooks::Output::PreToolUse.merge(
  hook1.output,
  hook2.output
)
# /!\ Called on the merged output
merged_output.output_and_exit  # Handles everything automatically
```

## Simplified Entrypoint Pattern

### For Single Hooks
```ruby
#!/usr/bin/env ruby
require 'claude_hooks'
require_relative '../handlers/my_hook'

# Super simple - just 3 lines!
ClaudeHooks::CLI.entrypoint do |input_data|
  hook = MyHook.new(input_data)
  hook.call
  hook.output_and_exit
end
```

### For Multiple Hooks with Merging
```ruby
#!/usr/bin/env ruby
require 'claude_hooks'
require_relative '../handlers/hook1'
require_relative '../handlers/hook2'

ClaudeHooks::CLI.entrypoint do |input_data|
  hook1 = Hook1.new(input_data)
  hook2 = Hook2.new(input_data)
  hook1.call
  hook2.call
  
  merged = ClaudeHooks::Output::PreToolUse.merge(
    hook1.output,
    hook2.output
  )
  # /!\ Called on the merged output
  merged.output_and_exit
end
```

## All Supported Hook Types

- `ClaudeHooks::Output::UserPromptSubmit`
- `ClaudeHooks::Output::PreToolUse` 
- `ClaudeHooks::Output::PostToolUse`
- `ClaudeHooks::Output::Stop`
- `ClaudeHooks::Output::SubagentStop`
- `ClaudeHooks::Output::Notification`
- `ClaudeHooks::Output::SessionStart`
- `ClaudeHooks::Output::PreCompact`

Each handles the specific exit code logic and semantic helpers for its hook type.

## Migration Steps

1. **Update your hook handlers** to return `output_data` (most already do)
2. **Replace manual exit logic** with `hook.output_and_exit` or `output.output_and_exit`
3. **Use semantic helpers** instead of digging through hash structures
4. **Use output object merging** instead of class methods
5. **Enjoy the simplified, cleaner code!**

The old patterns still work for backward compatibility, but the new output objects make everything much cleaner and less error-prone.