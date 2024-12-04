ActiveSupport.on_load(:active_storage_record) do
  tenanted_with "ApplicationRecord"
end
