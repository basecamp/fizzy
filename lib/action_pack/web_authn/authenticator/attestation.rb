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

  delegate :credential_id, :public_key, :public_key_bytes, :sign_count, :aaguid, :backed_up?, to: :authenticator_data

  # Wraps raw attestation data into an Attestation instance. Accepts an
  # existing Attestation object (returned as-is), a Base64URL-encoded string,
  # or raw binary.
  def self.wrap(data)
    if data.is_a?(self)
      data
    else
      unless data.encoding == Encoding::BINARY
        # Base64URL expands 3 bytes into 4 characters, so an encoded value whose
        # decoded size would exceed the CBOR byte limit is rejected before
        # Base64.urlsafe_decode64 allocates the decoded copy.
        max_encoded = ActionPack::WebAuthn::CborDecoder::MAX_SIZE / 3 * 4 + 4
        if data.bytesize > max_encoded
          raise ActionPack::WebAuthn::InvalidResponseError, "Attestation object is too large"
        end

        data = Base64.urlsafe_decode64(data)
      end

      decode(data)
    end
  rescue ArgumentError
    raise ActionPack::WebAuthn::InvalidResponseError, "Invalid base64 encoding in attestation object"
  end

  # Decodes a CBOR-encoded attestation object into an Attestation instance.
  def self.decode(bytes)
    cbor = ActionPack::WebAuthn::CborDecoder.decode(bytes)

    unless cbor.is_a?(Hash) && cbor["authData"].is_a?(String)
      raise ActionPack::WebAuthn::InvalidResponseError, "Malformed attestation object"
    end

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
