#!/usr/bin/env ruby
# require 'claude_hooks' - loaded by entrypoint

class ShowContext < ClaudeHooks::UserPromptSubmit
  def call
    # Define your words to trigger the hook
    triggers = [ "show context", "show your context" ]

    # Iterate to find if any trigger words are present
    if triggers.any? { |trigger| current_prompt.downcase.include?(trigger.downcase) }

      # Use a Hook state method to modify what's sent back to Claude Code
      add_additional_context!(read_file)
      system_message!("\n--- \"Show Context\" hook ran successfully ---")

      # Record a log line.
      log "Context Successfully Added: --> Show Context"
    end

    # Return output if you need it
    output
  end

private

  def read_file
    # If we were in the project directory, we would use project_path_for instead
    file_path = project_path_for('hooks/handlers/user_prompt_submit/trigger_instructions/show-context.txt')

    if File.exist?(file_path)
      content = File.read(file_path).strip
      return content unless content.empty?
    end
    log "Rule file not found or empty at: #{file_path}", level: :warn
    nil
  end
end

# If this file is run directly (for testing), call the hook
if __FILE__ == $0
  ClaudeHooks::CLI.test_runner(ShowContext)
end
