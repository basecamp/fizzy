# = Action Pack WebAuthn
#
# Provides a pure-Ruby implementation of the WebAuthn (Web Authentication)
# specification for passkey registration and authentication. This module
# is the top-level namespace for all WebAuthn components and provides
# shared utilities used across ceremonies.
#
# == Components
#
# [ActionPack::WebAuthn::RelyingParty]
#   Identifies your application to authenticators.
#
# [ActionPack::WebAuthn::PublicKeyCredential]
#   Orchestrates registration and authentication ceremonies.
#
# [ActionPack::WebAuthn::Authenticator]
#   Parses and validates authenticator responses.
#
# [ActionPack::WebAuthn::CborDecoder]
#   Decodes CBOR-encoded data from authenticators.
#
# [ActionPack::WebAuthn::CoseKey]
#   Parses COSE public keys into OpenSSL key objects.
#
# == Extending Attestation Formats
#
# By default only the "none" attestation format is supported. Register
# additional verifiers with:
#
#   ActionPack::WebAuthn.register_attestation_verifier("packed", MyPackedVerifier.new)
#
module ActionPack::WebAuthn
  class InvalidResponseError < StandardError; end
  class InvalidCborError < StandardError; end
  class InvalidKeyError < StandardError; end
  class UnsupportedKeyTypeError < StandardError; end
  class InvalidOptionsError < StandardError; end

  class << self
    # Returns a new RelyingParty configured from the current request context.
    def relying_party
      RelyingParty.new
    end

    # Returns the MessageVerifier used to sign and verify WebAuthn challenges.
    def challenge_verifier
      Rails.application.message_verifier("action_pack.webauthn.challenge")
    end

    # Returns the registry of attestation format verifiers, keyed by format
    # string (e.g., "none", "packed"). Only "none" is registered by default.
    def attestation_verifiers
      @attestation_verifiers ||= {
        "none" => Authenticator::AttestationVerifiers::None.new
      }
    end

    # Registers a custom attestation verifier for the given +format+.
    # The +verifier+ must respond to +verify!(attestation, client_data_json:)+.
    def register_attestation_verifier(format, verifier)
      attestation_verifiers[format.to_s] = verifier
    end
  end
end
