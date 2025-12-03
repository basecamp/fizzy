#!/usr/bin/env ruby

require 'claude_hooks'

# Example hook module that logs user prompts to a file
class LogUserPrompt < ClaudeHooks::UserPromptSubmit

  def call
    log "Executing LogUserPrompt hook"

    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')

    log <<~TEXT
      Prompt: #{current_prompt}
      Logged user prompt (session: #{session_id})
    TEXT

    nil # ignored output
  end
end

# If this file is run directly (for testing), call the hook
if __FILE__ == $0
  ClaudeHooks::CLI.test_runner(LogUserPrompt)
end
