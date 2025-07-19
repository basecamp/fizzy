#
#  This environment is intended to be run in development for local performance testing, but with
#  production-like settings.
#
require_relative "production"

Rails.application.configure do
  config.active_storage.service = :local
  config.assume_ssl = false
  config.force_ssl = false
  config.action_controller.allow_forgery_protection = false

  # config.log_level = :info
  # config.structured_logging.logger = nil
end
