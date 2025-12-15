#!/usr/bin/env ruby

BACKFILL_TIMESTAMP = Time.parse("2025-12-16 00:00:00 UTC")
ACCOUNT_ID = nil # restrict to an account_id

# Split sibling <p> tags with content by inserting <p><br</p> to replicaate previous view.
# Run for the time range before paragraphs were not spaced
# See https://app.fizzy.do/5986089/cards/3472
# and https://github.com/basecamp/fizzy/pull/2107
#
# MUST BE RUN AFTER decrypt!
#
# Run locally:
#   bin/rails runner script/migrations/split-sibling-paragraphs-with-p-br.rb
#
# Run via Kamal:
#   kamal app exec -d <stage> -p --reuse "bin/rails runner script/migrations/split-sibling-paragraphs-with-p-br.rb"
#
# Safe to re-run for a time range: won't re-detect unsplit paragrpahs and updated_at will be outside time window
class SeparateSiblingParagraphs
  attr_reader :updated_at, :account_id

  def initialize(updated_at, account_id: nil)
    @updated_at = updated_at
    @account_id = account_id
  end

  def run
    puts "Separating non-blank sibling paragraphs"

    puts "Updated at: #{updated_at}"
    puts account_id ? "Only account id: #{account_id}" : "For **ALL ACCOUNTS**"

    puts "\nPress ENTER to continue running or CTRL-C to bail..."
    gets

    puts "\nRunning..."

    # Suppress SQL logs
    Rails.event.debug_mode = false

    seconds = Benchmark.realtime do
      suppressing_turbo_broadcasts do
        separate_nonblank_paragraphs
      end
    end

    puts "\n\n"
    puts "Finished splitting non-blank <p>s in %.2f seconds." % seconds
  end

  private
    def suppressing_turbo_broadcasts
      Board.suppressing_turbo_broadcasts do
        Card.suppressing_turbo_broadcasts do
          yield
        end
      end
    end

    def separate_nonblank_paragraphs
      scanned = 0
      fixed = 0
      insertions = 0

      action_texts_scope.find_each do |rich_text|
        next if account_id && rich_text.record.account.external_account_id != account_id

        scanned += 1
        edited = false

        rich_text.body.fragment.tap do |fragment|
          fragment.find_all("p + p").each do |node|
            unless ineligible?(node) || ineligible?(node.previous_sibling)
              node.add_previous_sibling empty_node_markup
              edited = true
              insertions += 1
            end
          end
        end.then do |fragment|
          if edited
            puts " - modifying #{rich_text.record.class.name} #{rich_text.record.to_param} (account: #{rich_text.record.account.external_account_id})"
            # allow implicit touching to invalidate caches
            rich_text.update! body: fragment.to_html
            fixed +=1
          end
        end
      end

      puts "\n\Separation complete!"
      puts "  Rich texts examined: #{scanned}"
      puts "  Rich texts modified: #{fixed}"
      puts "  Paragraphs inserted: #{insertions}"
      fixed
    end

    def action_texts_scope
      ActionText::RichText.where(updated_at: updated_at)
    end

    def ineligible?(node)
      empty_node?(node) || wrapping_attachment?(node)
    end

    def empty_node?(node)
      node.to_html == empty_node_markup
    end

    def empty_node_markup
      "<p><br></p>"
    end

    def wrapping_attachment?(node)
      node.children.first&.name == "action-text-attachment"
    end
end

SeparateSiblingParagraphs.new(..BACKFILL_TIMESTAMP, account_id: ACCOUNT_ID).run
