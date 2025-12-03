#!/usr/bin/env ruby

# Example of the NEW simplified entrypoint pattern using output objects
# Compare this to the existing user_prompt_submit.rb to see the difference!

require 'claude_hooks'
require 'json'
# Require the output classes
require_relative '../../../lib/claude_hooks/output/base'
require_relative '../../../lib/claude_hooks/output/user_prompt_submit'
require_relative '../handlers/user_prompt_submit/append_rules'
require_relative '../handlers/user_prompt_submit/log_user_prompt'

begin
  # Read input from stdin
  input_data = JSON.parse(STDIN.read)

  # Execute all hook scripts
  append_rules = AppendRules.new(input_data)
  append_rules.call

  log_user_prompt = LogUserPrompt.new(input_data)
  log_user_prompt.call

  merged_output = ClaudeHooks::Output::UserPromptSubmit.merge(
    append_rules.output,
    log_user_prompt.output
  )

  merged_output.output_and_exit

rescue StandardError => e
  # Same simple error pattern
  STDERR.puts JSON.generate({
    continue: false,
    stopReason: "Hook execution error: #{e.message} #{e.backtrace.join("\n")}",
    suppressOutput: false
  })
  exit 2
end