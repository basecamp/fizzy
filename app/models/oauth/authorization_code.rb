module Oauth::AuthorizationCode
  Details = ::Data.define(:client_id, :identity_id, :code_challenge, :redirect_uri, :scope)

  class << self
    def generate(client_id:, identity_id:, code_challenge:, redirect_uri:, scope:)
      payload = { client_id:, identity_id:, code_challenge:, redirect_uri:, scope: }
      encryptor.encrypt_and_sign(payload, expires_in: 60.seconds)
    end

    def parse(code)
      if code.present? && data = encryptor.decrypt_and_verify(code)
        Details.new \
          client_id: data["client_id"],
          identity_id: data["identity_id"],
          code_challenge: data["code_challenge"],
          redirect_uri: data["redirect_uri"],
          scope: data["scope"]
      end
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    def valid_pkce?(code_data, code_verifier)
      code_data && code_verifier.present? &&
        ActiveSupport::SecurityUtils.secure_compare(pkce_challenge(code_verifier), code_data.code_challenge)
    end

    private
      def encryptor
        @encryptor ||= ActiveSupport::MessageEncryptor.new \
          Rails.application.key_generator.generate_key("oauth/authorization_codes", 32)
      end

      def pkce_challenge(verifier)
        Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
      end
  end
end
