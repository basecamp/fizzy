#!/usr/bin/env ruby

# SessionEnd Entrypoint
#
# This entrypoint orchestrates all SessionEnd handlers when the session ends.
# Triggered when a Claude Code session ends (exit, clear, logout, etc.).
# It reads JSON input from STDIN, executes all configured handlers, merges their outputs,
# and returns the final result to Claude Code via STDOUT.

require 'claude_hooks'
require 'json'

# Require all SessionEnd handler classes
require_relative '../handlers/session_end/extract_transcript'

begin
  # Read input data from Claude Code
  input_data = JSON.parse($stdin.read)

  # Initialize and execute handler
  extract_handler = ExtractTranscript.new(input_data)
  extract_handler.call

  # Output result
  extract_handler.output_and_exit

rescue StandardError => e
  # Same simple error pattern
  STDERR.puts JSON.generate({
                              continue: false,
                              stopReason: "Hook execution error: #{e.message} #{e.backtrace.join("\n")}",
                              suppressOutput: false
                            })
  exit 2
end
