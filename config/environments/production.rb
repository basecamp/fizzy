require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Email provider Settings
  #
  # SMTP setting can be configured via environment variables.
  # For other configuration options, consult the Action Mailer documentation.
  if smtp_address = ENV["SMTP_ADDRESS"].presence
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: smtp_address,
      port: ENV.fetch("SMTP_PORT", ENV["SMTP_TLS"] == "true" ? "465" : "587").to_i,
      domain: ENV.fetch("SMTP_DOMAIN", nil),
      user_name: ENV.fetch("SMTP_USERNAME", nil),
      password: ENV.fetch("SMTP_PASSWORD", nil),
      authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain"),
      tls: ENV["SMTP_TLS"] == "true",
      openssl_verify_mode: ENV["SMTP_SSL_VERIFY_MODE"]
    }
  end

  # Base URL for links in emails and other external references.
  # Set BASE_URL to your instance's public URL (e.g., https://fizzy.example.com)
  if base_url = ENV["BASE_URL"].presence
    uri = URI.parse(base_url)
    url_options = { host: uri.host, protocol: uri.scheme }
    url_options[:port] = uri.port if uri.port != uri.default_port

    routes.default_url_options = url_options
    config.action_mailer.default_url_options = url_options
  end

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{5.minutes.to_i}"
  }

  # Select Active Storage service via env var; default to local disk.
  # Don't overwrite if it's already been set (e.g. by fizzy-saas)
  if config.active_storage.service.blank?
    config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "local").to_sym
  end

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Set DISABLE_SSL=true to disable all SSL options, rather than specify each individually
  ssl_enabled = "true" unless ENV["DISABLE_SSL"] == "true"

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
  config.assume_ssl = ENV.fetch("ASSUME_SSL", ssl_enabled) == "true"

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = ENV.fetch("FORCE_SSL", ssl_enabled) == "true"

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new(STDOUT)
                                       .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
                                       .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Use a different cache store in production.
  config.cache_store = :solid_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment).
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue, reading: :queue } }
  # config.active_job.queue_name_prefix = "fizzy_production"

  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # The OAuth authorization server ships dark: unless OAUTH_ACCEPTANCE_ENABLED is
  # "true" there is no discovery, registration, authorization or token endpoint,
  # and OAuth-issued tokens are refused. OAUTH_ISSUANCE_ENABLED=false pauses
  # minting while existing tokens keep working. OAUTH_PILOT_CLIENT_IDS
  # (comma-separated client_ids) exempts named clients from both switches.
  # See Oauth::Availability. Applies to beta and staging, which load this file.
  config.x.oauth.acceptance_enabled = ENV["OAUTH_ACCEPTANCE_ENABLED"] == "true"
  config.x.oauth.issuance_enabled = ENV["OAUTH_ISSUANCE_ENABLED"] != "false"
  config.x.oauth.pilot_client_ids = ENV.fetch("OAUTH_PILOT_CLIENT_IDS", "").split(",").map(&:strip).compact_blank

  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
