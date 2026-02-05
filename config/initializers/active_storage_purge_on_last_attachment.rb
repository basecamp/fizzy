# Fizzy-specific override: ActiveStorage's default purge path uses `delete`,
# which skips attachment callbacks. We need `destroy` so storage ledger detaches
# are recorded and reused blobs (ActionText embeds) aren't purged until the
# last attachment is gone. Keep this local to Fizzy; it's not a Rails default.
module ActiveStorage
  module PurgeOnLastAttachment
    def purge
      @purge_mode = :purge
      destroy
      purge_blob_if_last(:purge) if destroyed?
    ensure
      @purge_mode = nil
    end

    def purge_later
      @purge_mode = :purge_later
      destroy
      purge_blob_if_last(:purge_later) if destroyed?
    ensure
      @purge_mode = nil
    end

    private
      def purge_dependent_blob_later
        if (record.nil? || dependent == :purge_later) && !@purge_mode
          purge_blob_if_last(:purge_later)
        end
      end

      def purge_blob_if_last(mode)
        if blob && !blob.attachments.exists?
          mode == :purge ? blob.purge : blob.purge_later
        end
      end
  end
end

ActiveSupport.on_load(:active_storage_attachment) do
  prepend ActiveStorage::PurgeOnLastAttachment
end
