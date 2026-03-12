module ActionPack::Passkey::Request
  extend ActiveSupport::Concern

  included do
    before_action do
      ActionPack::WebAuthn::Current.host = request.host
      ActionPack::WebAuthn::Current.origin = request.base_url
      ActionPack::WebAuthn::Current.challenge = cookies.encrypted[:webauthn_challenge]
      cookies.delete(:webauthn_challenge)
    end
  end
end
