#!/usr/bin/env ruby

# Backfill storage ledger with attach entries for all existing attachments.
#
# Run locally:
#   bin/rails runner script/migrations/backfill-storage-ledger.rb
#
# Run via Kamal:
#   kamal app exec -d <stage> -p --reuse "bin/rails runner script/migrations/backfill-storage-ledger.rb"
#
# Safe to re-run: skips attachments that already have entries (by blob_id).
class BackfillStorageLedger
  def run
    puts "Backfilling storage entries…"
    backfill_entries

    puts "\nMaterializing totals…"
    materialize_totals
  end

  private
    def backfill_entries
      created = 0
      skipped = 0

      ActiveStorage::Attachment.includes(:blob).find_each do |attachment|
        record = attachment.record.try(:storage_tracked_record)

        if record.nil? || Storage::Entry.exists?(blob_id: attachment.blob_id)
          skipped += 1
          next
        end

        Storage::Entry.create! \
          account_id: record.account.id,
          board_id: record.board_for_storage_tracking&.id,
          recordable_type: record.class.name,
          recordable_id: record.id,
          blob_id: attachment.blob_id,
          delta: attachment.blob.byte_size,
          operation: "attach"
        created += 1

        print "." if created % 100 == 0
      end

      puts "\n\nBackfill complete!"
      puts "  Entries created: #{created}"
      puts "  Attachments skipped: #{skipped}"
    end

    def materialize_totals
      boards_materialized = 0
      accounts_materialized = 0

      Board.find_each do |board|
        board.materialize_storage
        boards_materialized += 1
        print "." if boards_materialized % 100 == 0
      end

      Account.find_each do |account|
        account.materialize_storage
        accounts_materialized += 1
      end

      puts "\n\nMaterialization complete!"
      puts "  Boards: #{boards_materialized}"
      puts "  Accounts: #{accounts_materialized}"
    end
end

BackfillStorageLedger.new.run
