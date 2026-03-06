Rails.application.config.to_prepare do
  ActionPack::WebAuthn::Passkey.include ActionPackWebAuthnInferPasskeyName
end
