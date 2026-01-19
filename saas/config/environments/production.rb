Rails.application.configure do
  config.active_storage.service = :s3

  # Enable structured logging
  config.structured_logging.logger = ActiveSupport::Logger.new(STDOUT)

  config.action_controller.default_url_options = { host: "fizzy.rexielabs.com", protocol: "https" }
  config.action_mailer.default_url_options     = { host: "fizzy.rexielabs.com", protocol: "https" }
  config.action_mailer.smtp_settings = { domain: "fizzy.rexielabs.com", address: "smtp-outbound", port: 25, enable_starttls_auto: false }

  # SaaS version of Fizzy is multi-tenanted
  config.x.multi_tenant.enabled = true

  # Content Security Policy
  config.x.content_security_policy.report_only = false
  config.x.content_security_policy.report_uri = "https://o4506758240337920.ingest.us.sentry.io/api/4510738303090688/security/?sentry_key=c3256250d8bd91f268a031b9219cc824" # gitleaks:allow (public DSN for CSP reports)
  config.x.content_security_policy.script_src = "https://challenges.cloudflare.com"
  config.x.content_security_policy.frame_src = "https://challenges.cloudflare.com"
  # config.x.content_security_policy.connect_src = "https://storage.basecamp.com"
end
