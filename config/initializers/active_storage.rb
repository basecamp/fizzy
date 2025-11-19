ActiveSupport.on_load(:active_storage_blob) do
  ActiveStorage::DiskController.after_action only: :show do
    expires_in 5.minutes, public: true
  end
end

# Use DB read/write splitting for Active Storage models
ActiveSupport.on_load(:active_storage_record) do
  # SQLite doesn't use separate replica databases
  if ENV.fetch("DATABASE_ADAPTER", "mysql") == "sqlite"
    connects_to database: { writing: :primary, reading: :primary }
  else
    connects_to database: { writing: :primary, reading: :replica }
  end
end
