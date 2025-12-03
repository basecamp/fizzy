# Plugin Hooks Examples

This directory demonstrates how to use the Claude Hooks Ruby DSL when creating plugin hooks for [Claude Code plugins](https://docs.claude.com/en/docs/claude-code/plugins).

## Overview

The Claude Hooks DSL works seamlessly with plugin development! When creating plugins, you can use the exact same Ruby DSL as you would for regular hooks. The only difference is that plugin hooks are referenced through `${CLAUDE_PLUGIN_ROOT}` in the plugin's `hooks/hooks.json` configuration file.

## Benefits of Using This DSL in Plugins

- ✨ **Same powerful abstractions** - All the helper methods, logging, and state management work identically
- 🔄 **Automatic output handling** - `output_and_exit` manages streams and exit codes correctly
- 📝 **Built-in logging** - Session-specific logs work out of the box
- 🛠️ **Configuration access** - Access both plugin and project configurations
- 🎯 **Type safety** - Strong typed hook classes for each event type

## Example Plugin Structure

```
my-formatter-plugin/
├── .claude-plugin/
│   └── plugin.json           # Plugin metadata
├── hooks/
│   ├── hooks.json            # Hook configuration (references scripts)
│   └── scripts/
│       └── formatter.rb      # Hook script using ClaudeHooks DSL
└── README.md
```

## Example: Code Formatter Plugin

### Plugin Configuration (`hooks/hooks.json`)

```json
{
  "description": "Automatic code formatting on file writes",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/formatter.rb",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### Hook Script (`hooks/scripts/formatter.rb`)

```ruby
#!/usr/bin/env ruby
require 'claude_hooks'

class PluginFormatter < ClaudeHooks::PostToolUse
  def call
    log "Plugin formatter executing from: #{ENV['CLAUDE_PLUGIN_ROOT']}"

    # Only format code files
    file_path = tool_input['file_path']
    return output unless should_format?(file_path)

    log "Formatting file: #{file_path}"

    # Perform formatting (example)
    if format_file(file_path)
      add_additional_context!("File formatted successfully: #{file_path}")
    else
      log "Failed to format #{file_path}", level: :warn
    end

    output
  end

  private

  def should_format?(file_path)
    # Example: only format Ruby files
    file_path.end_with?('.rb')
  end

  def format_file(file_path)
    # Your formatting logic here
    # For example, using rubocop or prettier
    return true  # Simulated success
  end
end

if __FILE__ == $0
  input_data = JSON.parse(STDIN.read)
  hook = PluginFormatter.new(input_data)
  hook.call
  hook.output_and_exit
end
```

## Environment Variables in Plugins

When your hook scripts run as part of a plugin, these environment variables are available:

| Variable              | Description                                            |
|-----------------------|--------------------------------------------------------|
| `CLAUDE_PLUGIN_ROOT`  | Absolute path to the plugin directory                  |
| `CLAUDE_PROJECT_DIR`  | Project root directory (where Claude Code was started) |
| `RUBY_CLAUDE_HOOKS_*` | All standard configuration environment variables       |

### Accessing Plugin Root in Your Hooks

```ruby
class MyPluginHook < ClaudeHooks::PreToolUse
  def call
    # Access plugin root
    plugin_root = ENV['CLAUDE_PLUGIN_ROOT']
    log "Plugin root: #{plugin_root}"

    # Load plugin-specific config files
    plugin_config_path = File.join(plugin_root, 'config', 'settings.json')

    # Your hook logic here
    output
  end
end
```

## Best Practices for Plugin Hooks

1. **Keep hooks focused** - Each hook should have a single, well-defined purpose
2. **Use logging extensively** - Helps users debug plugin behavior
3. **Handle errors gracefully** - Don't crash on unexpected input
4. **Document environment requirements** - If your plugin needs external tools (rubocop, prettier, etc.)
5. **Test thoroughly** - Test with various file types and scenarios

## Testing Plugin Hooks Locally

You can test your plugin hooks before publishing:

```bash
# Test the hook script directly
echo '{"session_id":"test","transcript_path":"/tmp/test","cwd":"/tmp","hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"test.rb"},"tool_response":{"success":true}}' | CLAUDE_PLUGIN_ROOT=/path/to/plugin ruby hooks/scripts/formatter.rb
```

Or use the CLI test runner:

```ruby
#!/usr/bin/env ruby
require 'claude_hooks'

class PluginFormatter < ClaudeHooks::PostToolUse
  # ... your implementation ...
end

if __FILE__ == $0
  ClaudeHooks::CLI.run_with_sample_data(PluginFormatter) do |input_data|
    input_data['tool_name'] = 'Write'
    input_data['tool_input'] = { 'file_path' => 'test.rb' }
    input_data['tool_response'] = { 'success' => true }
  end
end
```

## Resources

- [Official Plugin Documentation](https://docs.claude.com/en/docs/claude-code/plugins)
- [Plugin Components Reference](https://docs.claude.com/en/docs/claude-code/plugins-reference#hooks)
- [Hooks API Reference](../../docs/API/)
- [Claude Hooks Main README](../../README.md)

## Contributing Examples

If you create a plugin using this DSL, consider contributing an example! Open a PR or issue on the [claude_hooks repository](https://github.com/gabriel-dehan/claude_hooks).
