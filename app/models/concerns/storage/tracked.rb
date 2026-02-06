# Storage tracking is a business abstraction - we count what users upload.
# Original upload bytes only; variants/previews/derivatives excluded.
# Physical storage optimizations (deduplication, compression) don't affect quotas.
module Storage::Tracked
  extend ActiveSupport::Concern

  included do
    before_update :track_board_transfer, if: :board_transfer?
  end

  # Return self as the trackable record for storage entries
  def storage_tracked_record
    self
  end

  # Override in models where board is determined differently (e.g., Board itself)
  def board_for_storage_tracking
    board
  end

  # Total bytes for all attachments on this record
  def storage_bytes
    attachments_for_storage.sum { |a| a.blob.byte_size }
  end

  private
    def board_transfer?
      respond_to?(:will_save_change_to_board_id?) && will_save_change_to_board_id?
    end

    def track_board_transfer
      old_board = Board.find_by(id: attribute_in_database(:board_id))
      records = storage_transfer_records.compact
      return if records.empty?

      attachments_by_record = storage_attachments_for_records(records)

      attachments_by_record.each do |recordable, attachments|
        bytes = attachments.sum { |attachment| attachment.blob.byte_size }
        next if bytes.zero?

        # Debit old board
        if old_board
          Storage::Entry.record \
            account: account,
            board: old_board,
            recordable: recordable,
            delta: -bytes,
            operation: "transfer_out"
        end

        # Credit new board
        Storage::Entry.record \
          account: account,
          board: board,
          recordable: recordable,
          delta: bytes,
          operation: "transfer_in"
      end
    end

    def storage_transfer_records
      [ self ]
    end

    # Override if needed. Default = all direct attachments
    def attachments_for_storage(recordable = self)
      storage_attachments_for_records([ recordable ]).fetch(recordable, [])
    end

    def storage_attachments_for_records(recordables)
      records = Array(recordables).compact
      return {} if records.empty?

      # Build lookup for records by (type, id) to avoid N+1 when resolving RichText parents
      records_by_key = records.index_by { |r| [ r.class.name, r.id ] }

      rich_texts = ActionText::RichText.where(record: records)
      rich_text_to_parent = rich_texts.to_h { |rt| [ rt.id, records_by_key[[ rt.record_type, rt.record_id ]] ] }

      attachments = ActiveStorage::Attachment
        .where(record: records + rich_texts)
        .includes(:blob)
        .to_a

      attachments.each_with_object(Hash.new { |h, k| h[k] = [] }) do |attachment, grouped|
        # Resolve parent without N+1: use lookup for RichText, direct for others
        recordable = if attachment.record_type == "ActionText::RichText"
          rich_text_to_parent[attachment.record_id]
        else
          records_by_key[[ attachment.record_type, attachment.record_id ]]
        end

        grouped[recordable] << attachment if recordable
      end
    end
end
