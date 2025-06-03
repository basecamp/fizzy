Rails.application.configure do
  config.middleware.insert_after ActiveRecord::Tenanted::TenantSelector, MovableWriter::Middleware::WriteCheck
end

Rails.application.config.after_initialize do
  MovableWriter::Record.subtenant_of "ApplicationRecord"
end
