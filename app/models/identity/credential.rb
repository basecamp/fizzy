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

    def register(passkey:, challenge:, origin: ActionPack::WebAuthn::Current.origin, **attributes)
      public_key_credential = ActionPack::WebAuthn::PublicKeyCredential.create(
        client_data_json: passkey[:client_data_json],
        attestation_object: Base64.urlsafe_decode64(passkey[:attestation_object]),
        challenge: challenge,
        origin: origin,
        transports: Array(passkey[:transports])
      )

      create!(
        **attributes,
        name: attributes.fetch(:name, Authenticator.find_by_aaguid(public_key_credential.aaguid)&.name),
        credential_id: public_key_credential.id,
        public_key: public_key_credential.public_key.to_der,
        sign_count: public_key_credential.sign_count,
        aaguid: public_key_credential.aaguid,
        backed_up: public_key_credential.backed_up,
        transports: public_key_credential.transports
      )
    end

    def authenticate(passkey:, challenge:, origin: ActionPack::WebAuthn::Current.origin)
      find_by(credential_id: passkey[:id])&.authenticate(passkey: passkey, challenge: challenge, origin: origin)
    end
  end

  def authenticate(passkey:, challenge:, origin: ActionPack::WebAuthn::Current.origin)
    pkc = to_public_key_credential
    pkc.authenticate(
      client_data_json: passkey[:client_data_json],
      authenticator_data: Base64.urlsafe_decode64(passkey[:authenticator_data]),
      signature: Base64.urlsafe_decode64(passkey[:signature]),
      challenge: challenge,
      origin: origin
    )
    update!(sign_count: pkc.sign_count, backed_up: pkc.backed_up)
    self
  rescue ActionPack::WebAuthn::Authenticator::Response::InvalidResponseError
    nil
  end

  def authenticator
    Authenticator.find_by_aaguid(aaguid)
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
