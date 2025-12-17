require_relative "production"

Rails.application.configure do
  config.action_mailer.smtp_settings[:domain] = "fizzy-beta.37signals.com"
  config.action_mailer.smtp_settings[:address] = "smtp-outbound-staging"
  config.action_mailer.default_url_options     = { host: "fizzy-beta.37signals.com", protocol: "https" }
  config.action_controller.default_url_options = { host: "fizzy-beta.37signals.com", protocol: "https" }
end
