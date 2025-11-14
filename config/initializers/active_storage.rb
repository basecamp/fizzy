ActiveSupport.on_load(:active_storage_blob) do
  ActiveStorage::DiskController.after_action only: :show do
    expires_in 5.minutes, public: true
  end
end

# Use DB read/write splitting for Active Storage models
ActiveSupport.on_load(:active_storage_record) do
  connects_to database: { writing: :primary, reading: :replica }
end
