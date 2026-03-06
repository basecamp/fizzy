require_relative "../web_authn"

class ActionPack::WebAuthn::Railtie < Rails::Railtie
  config.action_pack = ActiveSupport::OrderedOptions.new
  config.action_pack.web_authn = ActiveSupport::OrderedOptions.new
  config.action_pack.web_authn.default_request_options = {}
  config.action_pack.web_authn.default_creation_options = {}
end
