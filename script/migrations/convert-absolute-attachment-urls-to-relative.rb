#!/usr/bin/env ruby

# Convert absolute attachment URLs in rich text content to relative paths.
# This fixes URLs that were stored with full hostnames (e.g., https://app.fizzy.do/...)
# making them portable across beta environments and host changes.
#
# MUST BE RUN AFTER `decrypt!` when using ActiveRecord Encryption
#
# Run locally:
#   bin/rails runner script/migrations/convert-absolute-attachment-urls-to-relative.rb --help
#
# Run via Kamal:
#   kamal app exec -d <stage> -p --reuse "bin/rails runner script/migrations/convert-absolute-attachment-urls-to-relative.rb --help"
#
# Safe to re-run: won't modify already-relative URLs

class ConvertAbsoluteAttachmentUrlsToRelative
  # Match absolute URLs pointing to Active Storage routes, keeping the account slug
  ABSOLUTE_URL_PATTERN = %r{https?://[^/]+(/\d+/rails/active_storage/[^"']+)}

  attr_reader :account, :dry_run

  def initialize(account_id: nil, dry_run: false)
    @account = Account.find_by(external_account_id: account_id)
    @dry_run = dry_run
  end

  def run
    puts "Converting absolute attachment URLs to relative paths"
    puts dry_run ? "DRY RUN MODE - no changes will be saved" : "LIVE MODE - changes will be saved"
    puts account ? "Only account: #{account.external_account_id} - #{account.name}" : "For **ALL ACCOUNTS**"

    puts "\nPress ENTER to continue running or CTRL-C to bail..."
    gets

    puts "\nRunning..."

    # Suppress SQL logs
    Rails.event.debug_mode = false

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

          if url.match?(ABSOLUTE_URL_PATTERN)
            node["url"] = url.gsub(ABSOLUTE_URL_PATTERN, '\1')
            edited = true
            conversions += 1
          end
        end

        if edited
          record = rich_text.record
          puts " - modifying #{record.class.name} #{record.to_param} (account: #{record.account&.external_account_id}) - #{conversions} URL(s)"

          unless dry_run
            rich_text.update! body: body.fragment.to_html
          end

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
      # Only examine rich texts that have embedded attachments
      scope = ActionText::RichText.joins(:embeds_attachments)
      scope = scope.where(account: account) if account
      scope
    end
end

require "optparse"

options = { account_id: nil, dry_run: true }

OptionParser.new do |opts|
  opts.banner = "Usage: bin/rails runner #{__FILE__} [options]"

  opts.on("-a", "--account ACCOUNT_ID", "Restrict to a specific account (external_account_id)") do |id|
    options[:account_id] = id
  end

  opts.on("--[no-]dry-run", "Run in dry-run mode (default: --dry-run)") do |v|
    options[:dry_run] = v
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

ConvertAbsoluteAttachmentUrlsToRelative.new(**options).run
