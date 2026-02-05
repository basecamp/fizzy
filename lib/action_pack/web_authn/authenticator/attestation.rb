# = Action Pack WebAuthn Attestation
#
# Decodes and represents the attestation object returned by an authenticator
# during registration. The attestation object is CBOR-encoded and contains
# the authenticator data along with an optional attestation statement.
#
# == Usage
#
#   attestation = ActionPack::WebAuthn::Authenticator::Attestation.decode(
#     attestation_object_bytes
#   )
#
#   attestation.credential_id  # => "abc123..."
#   attestation.public_key     # => OpenSSL::PKey::EC
#   attestation.sign_count     # => 0
#
# == Attributes
#
# [+authenticator_data+]
#   The parsed Data containing credential information.
#
# [+format+]
#   The attestation statement format (e.g., "none", "packed", "fido-u2f").
#
# [+attestation_statement+]
#   The attestation statement, which may contain a signature from the
#   authenticator manufacturer. Empty for "none" format.
#
# == Delegated Methods
#
# The following methods are delegated to +authenticator_data+:
#
# * +credential_id+ - Base64URL-encoded credential identifier
# * +public_key+ - OpenSSL public key object
# * +public_key_bytes+ - Raw COSE key bytes
# * +sign_count+ - Signature counter for replay detection
#
class ActionPack::WebAuthn::Authenticator::Attestation
  attr_reader :authenticator_data, :format, :attestation_statement

  delegate :credential_id, :public_key, :public_key_bytes, :sign_count, to: :authenticator_data

  def self.decode(bytes)
    cbor = ActionPack::WebAuthn::CborDecoder.decode(bytes)

    new(
      authenticator_data: ActionPack::WebAuthn::Authenticator::Data.decode(cbor["authData"]),
      format: cbor["fmt"],
      attestation_statement: cbor["attStmt"]
    )
  end

  def initialize(authenticator_data:, format:, attestation_statement:)
    @authenticator_data = authenticator_data
    @format = format
    @attestation_statement = attestation_statement
  end
end
