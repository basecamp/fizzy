# A transform for a blob whose stored file is already gone is moot: the missing key is permanent,
# so retrying can't succeed, and raising 500s requests that process variants immediately
# (config/initializers/action_text.rb) after their save has already committed.
#   e.g. when a user uploads a file but deletes it before the transform runs.
#
# Discard the job, reporting so a bug that deletes files still referenced would stay visible.
ActiveSupport.on_load :active_storage_blob do
  [ ActiveStorage::TransformJob, ActiveStorage::CreateVariantsJob ].each do |job|
    job.discard_on ActiveStorage::FileNotFoundError, report: true
  end
end
