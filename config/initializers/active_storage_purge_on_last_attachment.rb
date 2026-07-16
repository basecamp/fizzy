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
      # Rails registers `after_destroy_commit :purge_dependent_blob` (renamed from
      # `purge_dependent_blob_later` upstream, which also now handles dependent: :purge).
      # Override the current callback name so reused blobs (ActionText embeds) are only
      # purged once the last attachment is gone, and skip when an explicit purge/purge_later
      # is already driving the blob purge via `purge_blob_if_last` (@purge_mode set).
      def purge_dependent_blob
        return if @purge_mode

        # `record.nil?` must be checked first: `dependent` reads `record.attachment_reflections`,
        # so it can't be evaluated for an orphaned attachment — an absent record falls back to
        # purge_later.
        if record.nil? || dependent == :purge_later
          purge_blob_if_last(:purge_later)
        elsif dependent == :purge
          purge_blob_if_last(:purge)
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
