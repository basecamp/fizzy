module Storage::AttachmentTracking
  extend ActiveSupport::Concern

  included do
    # Snapshot IDs in before_destroy since parent record may be deleted
    # by the time after_destroy_commit runs
    before_destroy :snapshot_storage_context
    after_create_commit :record_storage_attach
    after_destroy_commit :record_storage_detach
  end

  private
    def record_storage_attach
      return unless storage_tracked_record

      Storage::Entry.record \
        account: storage_tracked_record.account,
        board: storage_tracked_record.board_for_storage_tracking,
        recordable: storage_tracked_record,
        blob: blob,
        delta: blob.byte_size,
        operation: "attach"
    end

    def record_storage_detach
      return unless @storage_snapshot

      Storage::Entry.record \
        account_id: @storage_snapshot[:account_id],
        board_id: @storage_snapshot[:board_id],
        recordable_type: @storage_snapshot[:recordable_type],
        recordable_id: @storage_snapshot[:recordable_id],
        blob_id: @storage_snapshot[:blob_id],
        delta: -blob.byte_size,
        operation: "detach"
    end

    def snapshot_storage_context
      return unless storage_tracked_record

      @storage_snapshot = {
        account_id: storage_tracked_record.account.id,
        board_id: storage_tracked_record.board_for_storage_tracking&.id,
        recordable_type: storage_tracked_record.class.name,
        recordable_id: storage_tracked_record.id,
        blob_id: blob.id
      }
    end

    def storage_tracked_record
      record.try(:storage_tracked_record)
    end
end
