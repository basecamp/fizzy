#!/usr/bin/env ruby

# Rollback script: Convert relative attachment URLs back to absolute URLs.
# Use this if you need to rollback the relative URL changes and want to
# convert rich texts created during the rollout back to absolute URLs.
#
# Run locally:
#   bin/rails runner script/migrations/convert-relative-attachment-urls-to-absolute.rb --help
#
# Run via Kamal:
#   kamal app exec -d <stage> -p --reuse "bin/rails runner script/migrations/convert-relative-attachment-urls-to-absolute.rb --help"

class ConvertRelativeAttachmentUrlsToAbsolute
  # Match relative URLs pointing to Active Storage routes (with account slug)
  RELATIVE_URL_PATTERN = %r{\A(/\d+/rails/active_storage/[^"']+)\z}

  attr_reader :host, :since

  def initialize(host:, since:)
    @host = host
    @since = since
  end

  def run
    puts "Converting relative attachment URLs to absolute URLs"
    puts "Host: #{host}"
    puts "Processing rich texts created since: #{since}"

    puts "\nPress ENTER to continue running or CTRL-C to bail..."
    gets

    puts "\nRunning..."

    seconds = Benchmark.realtime do
      suppressing_turbo_broadcasts do
        convert_urls
      end
    end

    puts "\n\n"
    puts "Finished in %.2f seconds." % seconds
  end

  private
    def suppressing_turbo_broadcasts
      Board.suppressing_turbo_broadcasts do
        Card.suppressing_turbo_broadcasts do
          yield
        end
      end
    end

    def convert_urls
      scanned = 0
      fixed = 0
      urls_converted = 0

      action_texts_scope.find_each do |rich_text|
        scanned += 1

        body = rich_text.body

        edited = false
        conversions = 0

        body.send(:attachment_nodes).each do |node|
          url = node["url"]
          next unless url

          if url.match?(RELATIVE_URL_PATTERN)
            node["url"] = "#{host}#{url}"
            edited = true
            conversions += 1
          end
        end

        if edited
          record = rich_text.record
          puts " - modifying #{record.class.name} #{record.to_param} (account: #{record.account&.external_account_id}) - #{conversions} URL(s)"

          rich_text.update! body: body.fragment.to_html

          fixed += 1
          urls_converted += conversions
        end
      end

      puts "\n\nConversion complete!"
      puts "  Rich texts examined: #{scanned}"
      puts "  Rich texts modified: #{fixed}"
      puts "  URLs converted: #{urls_converted}"
    end

    def action_texts_scope
      ActionText::RichText.joins(:embeds_attachments).where("action_text_rich_texts.created_at >= ?", since)
    end
end

require "optparse"
require "time"

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: bin/rails runner #{__FILE__} [options]"

  opts.on("--host HOST", "Host to prepend (e.g., https://app.fizzy.do)") do |host|
    options[:host] = host
  end

  opts.on("--since TIME", "Process rich texts created since this time (ISO 8601 format)") do |time|
    options[:since] = Time.parse(time)
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

if options[:host].nil? || options[:since].nil?
  puts "Error: --host and --since are required"
  puts "Example: bin/rails runner #{__FILE__} --host https://app.fizzy.do --since 2026-01-14T10:00:00Z"
  exit 1
end

ConvertRelativeAttachmentUrlsToAbsolute.new(**options).run
