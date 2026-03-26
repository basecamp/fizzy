Rails.application.config.to_prepare do
  ActionPack::Passkey.prepend ActionPackPasskeyInferNameFromAaguid
end
