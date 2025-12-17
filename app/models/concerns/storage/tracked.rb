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
      respond_to?(:board_id_changed?) && board_id_changed?
    end

    def track_board_transfer
      old_board_id = board_id_was
      current_bytes = storage_bytes

      if current_bytes.positive?
        # Debit old board
        if old_board_id
          Storage::Entry.record \
            account: account,
            board_id: old_board_id,
            recordable: self,
            delta: -current_bytes,
            operation: "transfer_out"
        end

        # Credit new board
        Storage::Entry.record \
          account: account,
          board: board,
          recordable: self,
          delta: current_bytes,
          operation: "transfer_in"
      end
    end

    # Override if needed. Default = all direct attachments
    def attachments_for_storage
      ActiveStorage::Attachment.where(record: self)
    end
end
