class ActionPack::WebAuthn::Passkey < ApplicationRecord
  self.table_name = "passkeys"

  belongs_to :holder, polymorphic: true
  serialize :transports, coder: JSON, type: Array, default: []

  class << self
    def request_options(holder: nil, **options)
      ActionPack::WebAuthn::PublicKeyCredential.request_options(
        **Rails.configuration.action_pack.web_authn.default_request_options.to_h,
        **holder&.passkey_request_options.to_h,
        **options
      )
    end

    def authenticate(passkey:, challenge:)
      find_by(credential_id: passkey[:id])&.authenticate(passkey: passkey, challenge: challenge)
    end

    def creation_options(holder:, **options)
      ActionPack::WebAuthn::PublicKeyCredential.creation_options(
        **Rails.configuration.action_pack.web_authn.default_creation_options.to_h,
        **holder.passkey_creation_options.to_h,
        **options
      )
    end

    def register(passkey:, challenge:, **attributes)
      credential = ActionPack::WebAuthn::PublicKeyCredential.register(passkey, challenge: challenge)

      create!(**credential.to_h, **attributes)
    end
  end

  def authenticate(passkey:, challenge:)
    credential = to_public_key_credential
    credential.authenticate(passkey, challenge: challenge)
    update!(sign_count: credential.sign_count, backed_up: credential.backed_up)
    self
  rescue ActionPack::WebAuthn::InvalidAuthenticationResponseError
    nil
  end


  def to_public_key_credential
    ActionPack::WebAuthn::PublicKeyCredential.new(
      id: credential_id,
      public_key: public_key,
      sign_count: sign_count,
      transports: transports
    )
  end
end
