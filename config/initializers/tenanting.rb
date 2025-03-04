Rails.application.configure do |config|
  config.middleware.use ActiveRecord::Tenanted::TenantSelector, "ApplicationRecord", ->(request) { request.subdomain }
end
