# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV.fetch("SENTRY_DSN")
  config.breadcrumbs_logger = %i[ active_support_logger http_logger ]
  config.send_default_pii = false
  config.release = ENV.fetch("KAMAL_VERSION", "fizzy-dev")
  config.traces_sample_rate = 1.0
  config.enable_metrics = true

  # Queue time from reverse proxy (X-Request-Start header) — enabled by default
  config.capture_queue_time = true

  config.rails.register_error_subscriber = true
end

require "sentry-yabeda"

# Start periodic collection of Yabeda gauge metrics (GC, GVL, Puma).
# These plugins register collect blocks designed for Prometheus's pull model;
# the collector triggers them on a timer so metrics flow to Sentry instead.
Sentry::Yabeda.start_collector!
