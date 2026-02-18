class Identity::Credential < ApplicationRecord
  belongs_to :identity

  serialize :transports, coder: JSON, type: Array, default: []

  def authenticate(client_data_json:, authenticator_data:, signature:, challenge:, origin:)
    public_key_credential.authenticate(
      client_data_json: client_data_json,
      authenticator_data: authenticator_data,
      signature: signature,
      challenge: challenge,
      origin: request.base_url
    )
    increment!(:sign_count)
  end

  def to_public_key_credential
    ActionPack::WebAuthn::PublicKeyCredential.new(
      id: credential_id,
      public_key: OpenSSL::PKey.read(public_key),
      sign_count: sign_count,
      transports: transports
    )
  end
end
