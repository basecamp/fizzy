#!/usr/bin/env ruby

require 'claude_hooks'
require 'json'

class ContextLoader < ClaudeHooks::SessionStart
  CONFIG_PATH = 'config/config.json'

  def call
    log "Loading project context from config..."

    config_data = load_config
    return output unless config_data

    context = build_context(config_data)

    if context
      add_additional_context!(context)
      log "Context loaded successfully"

      # Uncomment to see full context being sent to Claude
      log "=== CONTEXT SENT TO CLAUDE ===\n#{context}\n=== END CONTEXT ==="
    else
      log "No context to load", level: :warn
    end

    output
  end

private

  def load_config
    config_file = project_path_for(CONFIG_PATH)

    unless File.exist?(config_file)
      log "Config file not found at: #{config_file}", level: :warn
      return nil
    end

    begin
      JSON.parse(File.read(config_file))
    rescue JSON::ParserError => e
      log "Failed to parse config JSON: #{e.message}", level: :error
      nil
    rescue StandardError => e
      log "Error loading config: #{e.message}", level: :error
      nil
    end
  end

  def build_context(config)
    files = config['contextPreLoad'] || []
    return nil if files.empty?

    begin_text = config['preLoadBegin'] || ''
    separator = config['preLoadSeparator'] || "\n\n"
    end_text = config['preLoadEnd'] || ''

    parts = [ begin_text ]

    files.each do |file_path|
      content = read_context_file(file_path)
      parts << content if content
    end

    # Join files with separator, then append end_text without separator
    parts.join(separator) + end_text
  end

  def read_context_file(relative_path)
    full_path = File.join(cwd, relative_path)

    unless File.exist?(full_path)
      log "Context file not found: #{relative_path}", level: :warn
      return nil
    end

    begin
      File.read(full_path).strip
    rescue StandardError => e
      log "Error reading #{relative_path}: #{e.message}", level: :error
      nil
    end
  end
end

# CLI testing
if __FILE__ == $0
  ClaudeHooks::CLI.test_runner(ContextLoader)
end
