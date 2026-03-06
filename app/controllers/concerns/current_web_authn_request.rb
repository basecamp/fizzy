module CurrentWebAuthnRequest
  extend ActiveSupport::Concern

  included do
    before_action do
      ActionPack::WebAuthn::Current.host = request.host
      ActionPack::WebAuthn::Current.origin = request.base_url
    end
  end
end
