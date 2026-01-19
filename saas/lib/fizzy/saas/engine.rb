require_relative "transaction_pinning"
require_relative "signup"
require_relative "authorization"
require_relative "../../rails_ext/active_record_tasks_database_tasks.rb"

module Fizzy
  module Saas
    class Engine < ::Rails::Engine
      initializer "fizzy_saas.content_security_policy", before: :load_config_initializers do |app|
        app.config.x.content_security_policy.form_action = "https://checkout.stripe.com https://billing.stripe.com"
      end

      initializer "fizzy_saas.assets" do |app|
        app.config.assets.paths << root.join("app/assets/stylesheets")
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

      # initializer "fizzy_saas.transaction_pinning" do |app|
      #   app.config.middleware.insert_after(ActiveRecord::Middleware::DatabaseSelector, TransactionPinning::Middleware)
      # end

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

        require_relative "metrics"
      end

      config.to_prepare do
        ::Account.include Account::Billing, Account::Limited
        CardsController.include(Card::LimitedCreation)
        Cards::PublishesController.include(Card::LimitedPublishing)

       Subscription::SHORT_NAMES.each do |short_name|
          const_name = "#{short_name}Subscription"
          ::Object.send(:remove_const, const_name) if ::Object.const_defined?(const_name)
          ::Object.const_set const_name, Subscription.const_get(short_name, false)
        end

        ::ApplicationController.include Fizzy::Saas::Authorization::Controller
        ::Identity.include Fizzy::Saas::Authorization::Identity
      end
    end
  end
end
