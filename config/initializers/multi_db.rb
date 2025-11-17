require "deployment"

Rails.application.configure do
  config.active_record.database_selector = { delay: 1.second }
  config.active_record.database_resolver = Deployment::DatabaseResolver
  config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
end
