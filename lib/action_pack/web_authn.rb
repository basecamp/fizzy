module ActionPack::WebAuthn
  class InvalidAuthenticationResponseError < StandardError; end
  class InvalidCborError < StandardError; end
  class UnsupportedKeyTypeError < StandardError; end

  class << self
    def relying_party
      RelyingParty.new
    end

    def attestation_verifiers
      @attestation_verifiers ||= {
        "none" => Authenticator::AttestationVerifiers::None.new
      }
    end

    def register_attestation_verifier(format, verifier)
      attestation_verifiers[format.to_s] = verifier
    end
  end
end
