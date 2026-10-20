Rails.application.configure do
  config.active_storage.service = :purestorage

  # Enable structured logging
  config.structured_logging.logger = ActiveSupport::Logger.new(STDOUT)

  config.action_controller.default_url_options = { host: "app.fizzy.do", protocol: "https" }
  config.action_mailer.default_url_options     = { host: "app.fizzy.do", protocol: "https" }
  config.action_mailer.smtp_settings = { domain: "app.fizzy.do", address: "smtp-outbound", port: 25, enable_starttls_auto: false }

  # SaaS version of Fizzy is multi-tenanted
  config.x.multi_tenant.enabled = true

  # Content Security Policy
  config.x.content_security_policy.report_only = false
  config.x.content_security_policy.report_uri = "https://o33603.ingest.us.sentry.io/api/4510481339187200/security/?sentry_key=9f126ba30d5f703451a13a2929bb5a10" # gitleaks:allow (public DSN for CSP reports)
  config.x.content_security_policy.script_src = "https://challenges.cloudflare.com"
  config.x.content_security_policy.frame_src = "https://challenges.cloudflare.com"
  config.x.content_security_policy.connect_src = "https://storage.basecamp.com"

  # Trusted Types report-only pilot: 1% of page loads report their DOM sink
  # writes to our own collector, which logs the sink and script location and
  # drops the content sample. CSP_TRUSTED_TYPES_SAMPLE_RATE=0 turns it off.
  config.x.content_security_policy.trusted_types_sample_rate = 0.01
  config.x.content_security_policy.trusted_types_report_uri = "/trusted_types_reports"
end
