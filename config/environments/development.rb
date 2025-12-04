require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing
  config.server_timing = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = { "Cache-Control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = true

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  if Rails.root.join("tmp/minio-dev.txt").exist?
    config.active_storage.service = :devminio
  else
    config.active_storage.service = :local
  end

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # Raise error when a before_action's only/except options reference missing actions
  config.action_controller.raise_on_missing_callback_actions = true

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Email delivery configuration
  # Priority: SMTP (if SMTP_HOST env var set) > letter_opener > console
  if ENV["SMTP_HOST"].present?
    # Use SMTP proxy (e.g., MailHog) for email delivery
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.smtp_settings = {
      address: ENV.fetch("SMTP_HOST", "mailhog"),
      port: ENV.fetch("SMTP_PORT", "1025").to_i,
      domain: ENV.fetch("SMTP_DOMAIN", "localhost"),
      # No authentication needed for MailHog
    }
  elsif Rails.root.join("tmp/email-dev.txt").exist?
    # Use letter_opener to preview emails in browser
    config.action_mailer.delivery_method = :letter_opener
    config.action_mailer.perform_deliveries = true
  else
    # Default: don't send emails, code shown in browser console
    config.action_mailer.raise_delivery_errors = false
  end

  # Allow localhost hosts for development
  # Note: Rails may check Host header with port included, so we match both
  config.hosts.clear
  config.hosts << "fizzy.localhost"
  config.hosts << "localhost"
  config.hosts << "127.0.0.1"
  config.hosts << /^fizzy-\d+(:\d+)?$/

  # Allow custom domains via ALLOWED_HOST_DOMAINS environment variable
  # Example: ALLOWED_HOST_DOMAINS=example.com,another.com
  if ENV["ALLOWED_HOST_DOMAINS"].present?
    ENV["ALLOWED_HOST_DOMAINS"].split(",").each do |domain|
      domain = domain.strip
      next if domain.empty?
      # Match domain and any subdomain, with optional port
      config.hosts << /\.#{Regexp.escape(domain)}(:\d+)?$/
      config.hosts << /^.*\.#{Regexp.escape(domain)}(:\d+)?$/
    end
  end

  # Set host to be used by links generated in mailer and notification view templates.
  config.action_controller.default_url_options = { host: config.hosts.first, port: 3006 }
  config.action_mailer.default_url_options     = { host: config.hosts.first, port: 3006 }
end
