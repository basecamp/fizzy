#!/usr/bin/env ruby

# SessionStart Entrypoint
#
# This entrypoint orchestrates all SessionStart handlers when the user starts a Claude Code session.
# It reads JSON input from STDIN, executes all configured handlers, merges their outputs,
# and returns the final result to Claude Code via STDOUT.

require 'claude_hooks'
require 'json'

# Require all SessionStart handler classes
require_relative '../handlers/session_start/tree_generator'
require_relative '../handlers/session_start/context_loader'

begin
  # Read input data from Claude Code
  input_data = JSON.parse($stdin.read)

  # Instantiate and run handlers
  tree_generator = TreeGenerator.new(input_data)
  tree_generator.call
  context_loader = ContextLoader.new(input_data)
  context_loader.call

  # Merge outputs
  merged_output = ClaudeHooks::Output::SessionStart.merge(
    tree_generator.output_data,
    context_loader.output_data
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
