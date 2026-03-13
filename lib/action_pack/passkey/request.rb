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

  def passkey_registration_params(param: :passkey)
    params.expect(param => [ :client_data_json, :attestation_object, transports: [] ])
  end

  def passkey_authentication_params(param: :passkey)
    params.expect(param => [ :id, :client_data_json, :authenticator_data, :signature ])
  end
end
