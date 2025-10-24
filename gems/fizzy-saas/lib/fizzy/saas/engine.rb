module Fizzy
  module Saas
    class Engine < ::Rails::Engine
      # moved from config/initializers/queenbee.rb
      Queenbee.host_app = Fizzy

      config.to_prepare do
        Queenbee::Subscription.short_names = Subscription::SHORT_NAMES
        Queenbee::ApiToken.token = Rails.application.credentials.dig(:queenbee_api_token)

        Subscription::SHORT_NAMES.each do |short_name|
          const_name = "#{short_name}Subscription"
          ::Object.send(:remove_const, const_name) if ::Object.const_defined?(const_name)
          ::Object.const_set const_name, Subscription.const_get(short_name, false)
        end
      end
    end
  end
end
