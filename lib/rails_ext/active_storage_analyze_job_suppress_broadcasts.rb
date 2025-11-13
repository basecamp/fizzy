# Avoid page refreshes from Active Storage analyzing blobs when these are attached.
#
# A better option would be to disable touching with +touch_attachment_records+ but
# there is currently a bug https://github.com/rails/rails/issues/55144
module ActiveStorageAnalyzeJobSuppressBroadcasts
  def perform(blob)
    Board.suppressing_turbo_broadcasts do
      Card.suppressing_turbo_broadcasts do
        super
      end
    end
  end
end

ActiveSupport.on_load :active_storage_blob do
  ActiveStorage::AnalyzeJob.prepend ActiveStorageAnalyzeJobSuppressBroadcasts
end
