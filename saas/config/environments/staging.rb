require_relative "production"

Rails.application.configure do
  config.action_mailer.smtp_settings[:domain] = "app.fizzy-staging.com"
  config.action_mailer.smtp_settings[:address] = "smtp-outbound-staging"
  config.action_mailer.default_url_options     = { host: "app.fizzy-staging.com", protocol: "https" }
  config.action_controller.default_url_options = { host: "app.fizzy-staging.com", protocol: "https" }
end
