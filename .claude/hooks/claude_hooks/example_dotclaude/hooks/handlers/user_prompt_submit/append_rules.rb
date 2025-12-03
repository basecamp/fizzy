#!/usr/bin/env ruby

require 'claude_hooks'

# Hook script that appends rules to user prompt
class AppendRules < ClaudeHooks::UserPromptSubmit

  def call
    log "Executing AppendRules hook"

    # Read the rules
    rules = read_rules

    if rules
      add_additional_context!(rules)
      log "Successfully added rules as additional context (#{rules.length} characters)"
    else
      log "No rule content found", level: :warn
    end

    output
  end

  private

  def read_rules
    # If we were in the project directory, we would use project_path_for instead
    rule_file_path = home_path_for('rules/post-user-prompt.rule.md')

    if File.exist?(rule_file_path)
      content = File.read(rule_file_path).strip
      return content unless content.empty?
    end

    log "Rule file not found or empty at: #{rule_file_path}", level: :warn
    # If we were in the project directory, we would use project_claude_dir instead
    log "Base directory: #{home_claude_dir}"
    nil
  end
end

# If this file is run directly (for testing), call the hook script
if __FILE__ == $0
  ClaudeHooks::CLI.test_runner(AppendRules) do |input_data|
    input_data['session_id'] = 'session-id-override-01'
  end
end
