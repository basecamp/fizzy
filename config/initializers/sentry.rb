if !Rails.env.local? && ENV["SKIP_TELEMETRY"].blank?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = %i[ active_support_logger http_logger ]
    config.send_default_pii = false
    config.release = ENV["GIT_REVISION"]
    config.excluded_exceptions += [ "ActiveRecord::ConcurrentMigrationError" ]
  end
end
