require "deployment"
require_relative "extensions"

if ActiveRecord::Base.replica_configured?
  Rails.application.configure do
    config.active_record.database_selector = { delay: 0.seconds }
    config.active_record.database_resolver = Deployment::DatabaseResolver
    config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
  end
end
