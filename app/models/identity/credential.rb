class Identity::Credential < ApplicationRecord
  belongs_to :identity

  serialize :transports, coder: JSON, type: Array, default: []

  class << self
    def creation_options(identity:, display_name:)
      ActionPack::WebAuthn::PublicKeyCredential::CreationOptions.new(
        id: identity.id,
        name: identity.email_address,
        display_name: display_name,
        resident_key: :required,
        exclude_credentials: identity.credentials.map(&:to_public_key_credential)
      )
    end

    def request_options(credentials: [])
      ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(credentials: credentials.map(&:to_public_key_credential))
    end

    def authenticate(id:, **params)
      find_by(credential_id: id)&.authenticate(**params)
    end

    def register(identity:, name:, client_data_json:, attestation_object:, challenge:, origin:, transports: [])
      public_key_credential = ActionPack::WebAuthn::PublicKeyCredential.create(
        client_data_json: Base64.urlsafe_decode64(client_data_json),
        attestation_object: Base64.urlsafe_decode64(attestation_object),
        challenge: challenge,
        origin: origin,
        transports: transports
      )

      identity.credentials.create!(
        name: name,
        credential_id: public_key_credential.id,
        public_key: public_key_credential.public_key.to_der,
        sign_count: public_key_credential.sign_count,
        transports: public_key_credential.transports
      )
    end
  end

  def authenticate(client_data_json:, authenticator_data:, signature:, challenge:, origin:)
    pkc = to_public_key_credential
    pkc.authenticate(
      client_data_json: client_data_json,
      authenticator_data: Base64.urlsafe_decode64(authenticator_data),
      signature: Base64.urlsafe_decode64(signature),
      challenge: challenge,
      origin: origin
    )
    update!(sign_count: pkc.sign_count)
    self
  rescue ActionPack::WebAuthn::Authenticator::Response::InvalidResponseError
    nil
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
