class Identity::Credential < ApplicationRecord
  belongs_to :identity

  serialize :transports, coder: JSON, type: Array, default: []

  def to_public_key_credential
    ActionPack::WebAuthn::PublicKeyCredential.new(
      id: credential_id,
      public_key: public_key,
      transports: transports
    )
  end
end
