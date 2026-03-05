class Passkey < ApplicationRecord
  belongs_to :holder, polymorphic: true

  serialize :transports, coder: JSON, type: Array, default: []

  class << self
    def creation_options(holder:, display_name:)
      ActionPack::WebAuthn::PublicKeyCredential.creation_options(
        id: holder.id,
        name: holder.email_address,
        display_name: display_name,
        resident_key: :required,
        exclude_credentials: holder.passkeys
      )
    end

    def request_options(credentials: [])
      ActionPack::WebAuthn::PublicKeyCredential.request_options(credentials: credentials)
    end

    def register(passkey:, challenge:, **attributes)
      credential = ActionPack::WebAuthn::PublicKeyCredential.register(passkey, challenge: challenge)

      create!(
        **credential.to_h,
        **attributes,
        name: attributes.fetch(:name, Authenticator.find_by_aaguid(credential.aaguid)&.name)
      )
    end

    def authenticate(passkey:, challenge:)
      find_by(credential_id: passkey[:id])&.authenticate(passkey: passkey, challenge: challenge)
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

  def authenticator
    Authenticator.find_by_aaguid(aaguid)
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
