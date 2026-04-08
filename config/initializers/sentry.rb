# frozen_string_literal: true

require "sentry-yabeda"

Sentry.init do |config|
  config.dsn = ENV.fetch("SENTRY_DSN")
  config.breadcrumbs_logger = %i[ active_support_logger http_logger ]
  config.send_default_pii = false
  config.release = ENV.fetch("KAMAL_VERSION", "fizzy-dev")
  config.traces_sample_rate = 1.0
  config.enable_metrics = true
  config.enable_logs = true

  # Queue time from reverse proxy (X-Request-Start header) — enabled by default
  config.capture_queue_time = true

  config.rails.register_error_subscriber = true
end
