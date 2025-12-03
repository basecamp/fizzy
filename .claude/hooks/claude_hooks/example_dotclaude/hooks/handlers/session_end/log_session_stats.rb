#!/usr/bin/env ruby

require 'claude_hooks'

class LogSessionStats < ClaudeHooks::SessionEnd
  def call
    log "Logging session statistics for session #{session_id}"
    
    # Generate session statistics
    stats = gather_session_stats
    
    # Log detailed statistics
    log <<~STATS
      === Session Statistics ===
      Session ID: #{session_id}
      End Reason: #{reason}
      Duration: #{stats[:duration]}
      Working Directory: #{cwd}
      Transcript Path: #{transcript_path}
      ===========================
    STATS
    
    # Log session summary
    log format_session_summary(stats)
    
    output
  end

  private

  def gather_session_stats
    {
      duration: calculate_session_duration,
      end_time: Time.now,
      transcript_size: get_transcript_size
    }
  end

  def calculate_session_duration
    # Example: could read session start time from transcript or file
    "Unknown (would need session start time)"
  end

  def get_transcript_size
    return 0 unless transcript_path && File.exist?(transcript_path)
    
    File.size(transcript_path)
  rescue StandardError => e
    log "Error getting transcript size: #{e.message}", level: :warn
    0
  end

  def format_session_summary(stats)
    "Session #{session_id} ended (#{reason}): #{stats[:transcript_size]} bytes transcript"
  end
end

# CLI testing support
if __FILE__ == $0
  ClaudeHooks::CLI.test_runner(LogSessionStats) do |input_data|
    input_data['reason'] ||= 'other'
    input_data['transcript_path'] ||= '/tmp/test_transcript'
  end
end