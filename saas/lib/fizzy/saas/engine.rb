require_relative "transaction_pinning"
require_relative "signup"
require_relative "authorization"
require_relative "gvl_instrumentation"
require_relative "../../rails_ext/active_record_tasks_database_tasks.rb"

module Fizzy
  module Saas
    class Engine < ::Rails::Engine
      # moved from config/initializers/queenbee.rb
      Queenbee.host_app = Fizzy

      # Configure ActionPushNative to use the saas database
      ActiveSupport.on_load(:action_push_native_record) do
        connects_to database: { writing: :saas, reading: :saas }
      end

      initializer "fizzy_saas.content_security_policy", before: :load_config_initializers do |app|
        app.config.x.content_security_policy.form_action = "https://checkout.stripe.com https://billing.stripe.com"
      end

      initializer "fizzy_saas.assets" do |app|
        app.config.assets.paths << root.join("app/assets/stylesheets")
      end

      initializer "fizzy_saas.public_files" do |app|
        app.middleware.insert_after ActionDispatch::Static, ActionDispatch::Static, root.join("public").to_s,
          headers: app.config.public_file_server.headers
      end

      initializer "fizzy_saas.push_config", after: "action_push_native.config" do |app|
        app.paths["config/push"].unshift(root.join("config/push.yml").to_s)
      end

      initializer "fizzy.saas.routes", after: :add_routing_paths do |app|
        # Routes that rely on the implicit account tenant should go here instead of in +routes.rb+.
        app.routes.prepend do
          namespace :account do
            resource :billing_portal, only: :show
            resource :subscription do
              scope module: :subscriptions do
                resource :upgrade, only: :create
                resource :downgrade, only: :create
              end
            end
          end

          namespace :stripe do
            resource :webhooks, only: :create
          end
        end
      end

      initializer "fizzy.saas.mount" do |app|
        app.routes.append do
          mount Fizzy::Saas::Engine => "/", as: "saas"
        end
      end

      initializer "fizzy_saas.transaction_pinning" do |app|
        app.config.middleware.insert_after(ActiveRecord::Middleware::DatabaseSelector, TransactionPinning::Middleware)
      end

      initializer "fizzy_saas.gvl_instrumentation" do |app|
        app.config.middleware.insert_before(Rack::Runtime, GvlInstrumentation)
      end

      initializer "fizzy_saas.solid_queue" do
        SolidQueue.on_start do
          Process.warmup
          Yabeda::Prometheus::Exporter.start_metrics_server!
        end
      end

      initializer "fizzy_saas.logging.session" do |app|
        ActiveSupport.on_load(:action_controller_base) do
          before_action do
            if Current.identity.present?
              logger.struct(authentication: { identity: { id: Current.identity.id } })
            end

            if Current.account.present?
              logger.struct(account: { queenbee_id: Current.account.external_account_id })
            end
          end
        end
      end

      # Load test mocks automatically in test environment
      initializer "fizzy_saas.test_mocks", after: :load_config_initializers do
        if Rails.env.test?
          require_relative "testing"
        end
      end

      initializer "fizzy_saas.stripe" do
        Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
      end

      initializer "fizzy_saas.sentry" do
        if !Rails.env.local? && ENV["SKIP_TELEMETRY"].blank?
          Sentry.init do |config|
            config.dsn = ENV["SENTRY_DSN"]
            config.breadcrumbs_logger = %i[ active_support_logger http_logger ]
            config.send_default_pii = false
            config.release = ENV["KAMAL_VERSION"]
            config.excluded_exceptions += [ "ActiveRecord::ConcurrentMigrationError" ]

            # Receive Rails.error.report and retry_on/discard_on report: true
            config.rails.register_error_subscriber = true
          end
        end
      end

      initializer "fizzy_saas.yabeda" do
        require "prometheus/client/support/puma"

        Prometheus::Client.configuration.logger = Rails.logger
        Prometheus::Client.configuration.pid_provider = Prometheus::Client::Support::Puma.method(:worker_pid_provider)
        Yabeda::Rails.config.controller_name_case = :camel
        Yabeda::Rails.config.ignore_actions = %w[
          Rails::HealthController#show
        ]

        Yabeda::ActiveJob.install!

        require "yabeda/solid_queue"
        Yabeda::SolidQueue.install!

        Yabeda::ActionCable.configure do |config|
          config.channel_class_name = "ActionCable::Channel::Base"
        end

        require "yabeda/gvl"
        Yabeda::GVL.install!

        require_relative "metrics"
      end

      config.before_initialize do
        config.console1984.protected_environments = %i[ production beta staging ]
        config.console1984.ask_for_username_if_empty = true
        config.console1984.base_record_class = "::SaasRecord"
        config.console1984.incinerate_after = 60.days

        config.audits1984.base_controller_class = "::Admin::AuditsController"
        config.audits1984.auditor_class = "::Identity"
        config.audits1984.auditor_name_attribute = :email_address

        if config.console1984.protected_environments.include?(Rails.env.to_sym)
          config.active_record.encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY")
          config.active_record.encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY")
          config.active_record.encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT")
        end
      end

      config.to_prepare do
        ::Account.include Account::Billing, Account::Limited
        ::User.include User::NotifiesAccountOfEmailChange
        ::Identity.include Authorization::Identity, Identity::Devices
        ::Session.include Session::Devices
        ::Signup.prepend Signup
        ApplicationController.include Authorization::Controller
        CardsController.include(Card::LimitedCreation)
        Cards::PublishesController.include(Card::LimitedPublishing)

        Notification.register_push_target(:native)

        Queenbee::Subscription.short_names = Subscription::SHORT_NAMES

        # Default to local dev QB token if not set
        Queenbee::ApiToken.token = ENV.fetch("QUEENBEE_API_TOKEN") { "69a4cfb8705913e6323f7b4c0c0cff9bd8df37da532f4375b85e9655b8100bb023591b48d308205092aa0a04dd28cb6c62d6798364a6f44cc1e675814eb148a1" } # gitleaks:allow development-only token

        Subscription::SHORT_NAMES.each do |short_name|
          const_name = "#{short_name}Subscription"
          ::Object.send(:remove_const, const_name) if ::Object.const_defined?(const_name)
          ::Object.const_set const_name, Subscription.const_get(short_name, false)
        end
      end
    end
  end
end
