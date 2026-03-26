require_relative "web_authn"

# = Action Pack Railtie
#
# Integrates the WebAuthn and Passkey subsystems into the Rails application.
# Configures default options for WebAuthn ceremonies and sets up the passkey
# challenge endpoint route.
#
# == Configuration
#
#   # config/application.rb or config/initializers/passkeys.rb
#   config.action_pack.web_authn.default_creation_options = { attestation: :none }
#   config.action_pack.web_authn.default_request_options  = { user_verification: :required }
#   config.action_pack.web_authn.creation_challenge_expiration = 10.minutes
#   config.action_pack.web_authn.request_challenge_expiration = 5.minutes
#
#   config.action_pack.passkey.routes_prefix = "/rails/action_pack/passkey"
#   config.action_pack.passkey.draw_routes   = true
#
class ActionPack::Railtie < Rails::Railtie
  config.action_pack = ActiveSupport::OrderedOptions.new unless config.respond_to?(:action_pack)

  config.action_pack.web_authn = ActiveSupport::OrderedOptions.new
  config.action_pack.web_authn.default_request_options = {}
  config.action_pack.web_authn.default_creation_options = {}
  config.action_pack.web_authn.creation_challenge_expiration = 10.minutes
  config.action_pack.web_authn.request_challenge_expiration = 5.minutes

  config.action_pack.passkey = ActiveSupport::OrderedOptions.new
  config.action_pack.passkey.parent_class_name = "ApplicationRecord"
  config.action_pack.passkey.routes_prefix = "/rails/action_pack/passkey"
  config.action_pack.passkey.draw_routes = true
  config.action_pack.passkey.challenge_url = nil

  initializer "action_pack.passkey.routes" do |app|
    passkey_config = config.action_pack.passkey

    app.routes.prepend do
      if passkey_config.draw_routes
        scope passkey_config.routes_prefix, as: :passkey do
          post "/challenge" => "action_pack/passkey/challenges#create", as: :challenge
        end
      end
    end
  end

  initializer "action_pack.passkey.holder" do
    ActiveSupport.on_load(:active_record) do
      # We need this shim because Holder is namespaced under Passkey, which is an ActiveRecord
      # and can't be required before ActiveRecord is loaded.
      def self.has_passkeys(**options, &block)
        include ActionPack::Passkey::Holder
        has_passkeys(**options, &block)
      end
    end
  end

  initializer "action_pack.passkey.form_helper" do
    ActiveSupport.on_load(:action_view) do
      require_relative "passkey/form_helper"
      include ActionPack::Passkey::FormHelper
    end
  end

  initializer "action_pack.passkey.request" do
    ActiveSupport.on_load(:action_controller) do
      require_relative "passkey/request"
    end
  end
end
