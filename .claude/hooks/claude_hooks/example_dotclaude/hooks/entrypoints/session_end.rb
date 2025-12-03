#!/usr/bin/env ruby

require 'json'
require_relative '../handlers/session_end/cleanup_handler'
require_relative '../handlers/session_end/log_session_stats'

begin
  # Read input from stdin
  input_data = JSON.parse(STDIN.read)

  # Initialize handlers
  cleanup_handler = CleanupHandler.new(input_data)
  log_handler = LogSessionStats.new(input_data)

  # Execute handlers
  cleanup_handler.call
  log_handler.call

  # Merge outputs using the SessionEnd output merger
  merged_output = ClaudeHooks::Output::SessionEnd.merge(
    cleanup_handler.output,
    log_handler.output
  )

  # Output result and exit with appropriate code
  merged_output.output_and_exit

rescue StandardError => e
  STDERR.puts JSON.generate({
    continue: false,
    stopReason: "Hook execution error: #{e.message}",
    suppressOutput: false
  })
  exit 2
end