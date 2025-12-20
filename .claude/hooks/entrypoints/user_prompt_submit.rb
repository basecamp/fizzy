#!/usr/bin/env ruby

# UserPromptSubmit Entrypoint
#
# This entrypoint orchestrates all UserPromptSubmit handlers when the user submits a prompt.
# It reads JSON input from STDIN, executes all configured handlers, merges their outputs,
# and returns the final result to Claude Code via STDOUT.

require 'claude_hooks'
require 'json'

# Require all UserPromptSubmit handler classes
# Add additional handler requires here as needed:

require_relative '../handlers/user_prompt_submit/claude_space'
require_relative '../handlers/user_prompt_submit/check_working'
require_relative '../handlers/user_prompt_submit/show_working'
require_relative '../handlers/user_prompt_submit/show_strategy'
require_relative '../handlers/user_prompt_submit/show_options'
require_relative '../handlers/user_prompt_submit/show_context'
require_relative '../handlers/user_prompt_submit/show_difficulties'

begin
  # Read input data from Claude Code
  input_data = JSON.parse($stdin.read)

  # Initialize and execute all handlers
  claude_space = ClaudeSpace.new(input_data)
  claude_space.call
  check_working = CheckWorking.new(input_data)
  check_working.call
  show_working = ShowWorking.new(input_data)
  show_working.call
  show_strategy = ShowStrategy.new(input_data)
  show_strategy.call
  show_options = ShowOptions.new(input_data)
  show_options.call
  show_context = ShowContext.new(input_data)
  show_context.call
  show_difficulties = ShowDifficulties.new(input_data)
  show_difficulties.call

  # # Use single handler output
  # show_working.output_and_exit

  # merge multiple if you add more handlers
  merged_output = ClaudeHooks::Output::UserPromptSubmit.merge(
    claude_space.output,
    check_working.output,
    show_working.output,
    show_strategy.output,
    show_options.output,
    show_context.output,
    show_difficulties.output
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
