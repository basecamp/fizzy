class Passkey < ApplicationRecord
  include ActionPack::WebAuthn::Passkey

  belongs_to :holder, polymorphic: true
  serialize :transports, coder: JSON, type: Array, default: []

  registration_attributes do |holder:, display_name:|
    {
      id: holder.id,
      name: holder.email_address,
      display_name: display_name,
      resident_key: :required,
      exclude_credentials: holder.passkeys
    }
  end

  after_authenticate do |credential|
    update!(sign_count: credential.sign_count, backed_up: credential.backed_up)
  end

  class << self
    def register(passkey:, challenge:, **attributes)
      super(passkey: passkey, challenge: challenge, **attributes).tap do |record|
        record.update!(name: record.authenticator&.name) if record.name.blank?
      end
    end
  end

  def authenticator
    Authenticator.find_by_aaguid(aaguid)
  end
end
