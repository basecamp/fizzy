module ActionPackWebAuthnInferePasskeyName
  extend ActiveSupport::Concern

  class_methods do
    def register(...)
      super(...).tap do |credential|
        credential.update!(name: authenticator.name) if authenticator && name.blank?
      end
    end
  end

  def authenticator
    Passkey::Authenticator.find_by_aaguid(aaguid)
  end
end
