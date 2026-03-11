require_relative "web_authn"

class ActionPack::Railtie < Rails::Railtie
  config.action_pack = ActiveSupport::OrderedOptions.new unless config.respond_to?(:action_pack)

  config.action_pack.web_authn = ActiveSupport::OrderedOptions.new
  config.action_pack.web_authn.default_request_options = {}
  config.action_pack.web_authn.default_creation_options = {}

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
