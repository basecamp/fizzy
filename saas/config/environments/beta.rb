require_relative "production"

Rails.application.configure do
  config.action_mailer.smtp_settings[:domain] = ENV.fetch("APP_FQDN", "fizzy-beta.com")
  config.action_mailer.smtp_settings[:address] = "smtp-outbound-staging"
  config.action_mailer.default_url_options     = { host: ENV.fetch("APP_FQDN", "fizzy-beta.com"), protocol: "https" }
  config.action_controller.default_url_options = { host: ENV.fetch("APP_FQDN", "fizzy-beta.com"), protocol: "https" }
end
