#!/usr/bin/env ruby

require 'claude_hooks'
require 'json'

class TreeGenerator < ClaudeHooks::SessionStart
  CONFIG_PATH = 'config/config.json'

  def call
    log "Generating tree structure..."

    config_data = load_config
    return output_data unless config_data

    folders = config_data['treeFolders'] || []
    exclude_patterns = config_data['treeExcludePatterns'] || []
    output_path = config_data['treeOutputPath']

    if folders.empty? || output_path.nil?
      log "Tree configuration incomplete, skipping", level: :warn
      suppress_output!
      return output_data
    end

    generate_tree(folders, exclude_patterns, output_path)
    suppress_output!

    output_data
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

  def generate_tree(folders, exclude_patterns, output_path)
    full_output_path = File.join(cwd, output_path)

    # Build exclude pattern for tree -I flag
    exclude_arg = exclude_patterns.empty? ? "" : "-I \"#{exclude_patterns.join('|')}\""

    # Build tree command with sed formatting
    command = "tree -a #{folders.join(' ')} #{exclude_arg} --dirsfirst | sed 's/\\xC2\\xA0/ /g' > #{full_output_path}"

    log "Executing: #{command}"

    begin
      result = `#{command} 2>&1`

      if $?.success?
        log "Tree generated successfully at #{output_path}"
      else
        log "Tree command failed: #{result}", level: :error
      end
    rescue StandardError => e
      log "Error executing tree command: #{e.message}", level: :error
    end
  end
end

# CLI testing
if __FILE__ == $0
  ClaudeHooks::CLI.test_runner(TreeGenerator)
end