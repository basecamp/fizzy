module ActionPack::WebAuthn::Passkey
  extend ActiveSupport::Concern

  class_methods do
    def request_options(credentials: [])
      ActionPack::WebAuthn::PublicKeyCredential.request_options(credentials: credentials)
    end

    def authenticate(passkey:, challenge:)
      find_by(credential_id: passkey[:id])&.authenticate(passkey: passkey, challenge: challenge)
    end

    def registration_attributes(&block)
      define_singleton_method(:_registration_attributes, &block)
    end

    def creation_options(**params)
      ActionPack::WebAuthn::PublicKeyCredential.creation_options(**_registration_attributes(**params))
    end

    def register(passkey:, challenge:, **attributes)
      credential = ActionPack::WebAuthn::PublicKeyCredential.register(passkey, challenge: challenge)

      create!(
        **credential.to_h,
        **attributes,
        name: attributes.fetch(:name, Authenticator.find_by_aaguid(credential.aaguid)&.name)
      )
    end

    def after_authenticate(method_name = nil, &block)
      block ||= ->(credential) { send(method_name, credential) }

      define_method(:after_authenticate_callback) do |credential|
        instance_exec(credential, &block)
      end
    end
  end

  def authenticate(passkey:, challenge:)
    credential = to_public_key_credential
    credential.authenticate(passkey, challenge: challenge)
    after_authenticate_callback(credential) if respond_to?(:after_authenticate_callback)
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
