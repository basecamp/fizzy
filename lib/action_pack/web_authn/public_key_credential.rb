class ActionPack::WebAuthn::PublicKeyCredential
  attr_reader :id, :public_key, :sign_count, :transports, :owner

  class << self
    def create(client_data_json:, attestation_object:, challenge:, origin:, transports: [], owner: nil)
      response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
        client_data_json: client_data_json,
        attestation_object: attestation_object
      )

      response.validate!(challenge: challenge, origin: origin)

      new(
        id: response.attestation.credential_id,
        public_key: response.attestation.public_key,
        sign_count: response.attestation.sign_count,
        transports: transports,
        owner: owner
      )
    end
  end

  def initialize(id:, public_key:, sign_count:, transports: [], owner: nil)
    @id = id
    @public_key = public_key
    @sign_count = sign_count
    @transports = transports
    @owner = owner
  end

  def authenticate(client_data_json:, authenticator_data:, signature:, challenge:, origin:)
    response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      client_data_json: client_data_json,
      authenticator_data: authenticator_data,
      signature: signature,
      credential: self
    )

    response.validate!(challenge: challenge, origin: origin)

    @sign_count = response.authenticator_data.sign_count
  end
end
