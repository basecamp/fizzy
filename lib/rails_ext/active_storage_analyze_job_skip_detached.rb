# Skip analysis for blobs whose attachments have already been destroyed.
#   e.g. when a user uploads a file but deletes it before the analysis runs.
# Avoids `Aws::S3::Errors::NoSuchKey` when an upload is deleted before AnalyzeJob runs.
module ActiveStorageAnalyzeJobSkipDetached
  def perform(blob)
    return unless blob.attachments.exists?

    super
  end
end

ActiveSupport.on_load :active_storage_blob do
  ActiveStorage::AnalyzeJob.prepend ActiveStorageAnalyzeJobSkipDetached
end
