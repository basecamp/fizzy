class ActionPack::WebAuthn::PublicKeyCredential
  attr_reader :id, :public_key, :sign_count, :aaguid, :backed_up, :transports

  class << self
    def request_options(**attributes)
      attributes[:credentials] = transform_credentials(attributes[:credentials]) if attributes[:credentials]

      ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(**attributes)
    end

    def creation_options(**attributes)
      attributes[:exclude_credentials] = transform_credentials(attributes[:exclude_credentials]) if attributes[:exclude_credentials]

      ActionPack::WebAuthn::PublicKeyCredential::CreationOptions.new(**attributes)
    end

    def register(params, challenge: ActionPack::WebAuthn::Current.challenge, origin: ActionPack::WebAuthn::Current.origin)
      response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
        client_data_json: params[:client_data_json],
        attestation_object: params[:attestation_object],
        challenge: challenge,
        origin: origin
      )

      response.validate!

      new(
        id: response.attestation.credential_id,
        public_key: response.attestation.public_key,
        sign_count: response.attestation.sign_count,
        aaguid: response.attestation.aaguid,
        backed_up: response.attestation.backed_up?,
        transports: Array(params[:transports])
      )
    end

    private
      def transform_credentials(credentials)
        Array(credentials).map do |credential|
          if credential.respond_to?(:to_public_key_credential)
            credential.to_public_key_credential
          else
            credential
          end
        end
      end
  end

  def initialize(id:, public_key:, sign_count:, aaguid: nil, backed_up: nil, transports: [])
    @id = id
    @public_key = public_key
    @public_key = OpenSSL::PKey.read(public_key) unless public_key.is_a?(OpenSSL::PKey::PKey)
    @sign_count = sign_count
    @aaguid = aaguid
    @backed_up = backed_up
    @transports = transports
  end

  def authenticate(params, challenge: ActionPack::WebAuthn::Current.challenge, origin: ActionPack::WebAuthn::Current.origin)
    response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      client_data_json: params[:client_data_json],
      authenticator_data: params[:authenticator_data],
      signature: params[:signature],
      credential: self,
      challenge: challenge,
      origin: origin
    )

    response.validate!

    @sign_count = response.authenticator_data.sign_count
    @backed_up = response.authenticator_data.backed_up?
  end

  def to_h
    {
      credential_id: id,
      public_key: public_key.to_der,
      sign_count: sign_count,
      aaguid: aaguid,
      backed_up: backed_up,
      transports: transports
    }
  end
end
