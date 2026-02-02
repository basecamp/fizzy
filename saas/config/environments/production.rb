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
end
