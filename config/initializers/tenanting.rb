ActiveSupport.on_load(:active_storage_record) do
  tenanted_with "ApplicationRecord"
end

Rails.application.configure do
  require "middleware/tenant_selector"
  config.middleware.use Middleware::TenantSelector
end
