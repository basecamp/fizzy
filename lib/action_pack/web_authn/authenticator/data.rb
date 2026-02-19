# = Action Pack WebAuthn Authenticator Data
#
# Decodes and represents the authenticator data structure from WebAuthn
# responses. This binary format contains information about the authenticator
# and, during registration, the newly created credential.
#
# == Structure
#
# The authenticator data consists of:
#
# * RP ID Hash (32 bytes) - SHA-256 hash of the relying party ID
# * Flags (1 byte) - Bit flags for user presence, verification, etc.
# * Sign Count (4 bytes) - Signature counter for replay detection
# * Attested Credential Data (variable) - Present only during registration
#
# == Usage
#
#   data = ActionPack::WebAuthn::Authenticator::Data.decode(bytes)
#
#   data.user_present?   # => true
#   data.user_verified?  # => true
#   data.sign_count      # => 42
#   data.credential_id   # => "abc123..." (registration only)
#   data.public_key      # => OpenSSL::PKey::EC (registration only)
#
# == Flags
#
# [+user_present?+]
#   Returns true if the user performed a test of user presence (e.g., touched
#   the authenticator).
#
# [+user_verified?+]
#   Returns true if the user was verified through biometrics, PIN, or other
#   method. This is stronger than mere presence.
#
# [+backup_eligible?+]
#   Returns true if the credential can be backed up (e.g., synced passkeys
#   from Apple, Google, or Microsoft). Indicates multi-device credential support.
#
# [+backed_up?+]
#   Returns true if the credential is currently backed up to cloud storage.
#   Useful for risk assessment—backed-up credentials may be accessible from
#   multiple devices.
#
class ActionPack::WebAuthn::Authenticator::Data
  # Segment lengths
  RELYING_PARTY_ID_HASH_LENGTH = 32
  FLAGS_LENGTH = 1
  SIGN_COUNT_LENGTH = 4
  AAGUID_LENGTH = 16
  CREDENTIAL_ID_LENGTH_BYTES = 2

  # Flags
  USER_PRESENT_FLAG = 0x01
  USER_VERIFIED_FLAG = 0x04
  BACKUP_ELIGIBLE_FLAG = 0x08
  BACKUP_STATE_FLAG = 0x10
  ATTESTED_CREDENTIAL_DATA_FLAG = 0x40

  attr_reader :bytes, :relying_party_id_hash, :flags, :sign_count, :aaguid, :credential_id, :public_key_bytes

  class << self
    def wrap(data)
      if data.is_a?(self)
        data
      else
        decode(data)
      end
    end

    def decode(bytes)
      bytes = bytes.bytes if bytes.is_a?(String)
      position = 0

      relying_party_id_hash = bytes[position, RELYING_PARTY_ID_HASH_LENGTH].pack("C*")
      position += RELYING_PARTY_ID_HASH_LENGTH

      flags = bytes[position]
      position += FLAGS_LENGTH

      sign_count = bytes[position, SIGN_COUNT_LENGTH].pack("C*").unpack1("N")
      position += SIGN_COUNT_LENGTH

      aaguid = nil
      credential_id = nil
      public_key_bytes = nil

      if flags & ATTESTED_CREDENTIAL_DATA_FLAG != 0
        aaguid_bytes = bytes[position, AAGUID_LENGTH].pack("C*")
        aaguid = aaguid_bytes.unpack("H8H4H4H4H12").join("-")
        position += AAGUID_LENGTH

        credential_id_length = bytes[position, CREDENTIAL_ID_LENGTH_BYTES].pack("C*").unpack1("n")
        position += CREDENTIAL_ID_LENGTH_BYTES

        credential_id = Base64.urlsafe_encode64(bytes[position, credential_id_length].pack("C*"), padding: false)
        position += credential_id_length

        public_key_bytes = bytes[position..].pack("C*")
      end

      new(
        bytes: bytes,
        relying_party_id_hash: relying_party_id_hash,
        flags: flags,
        sign_count: sign_count,
        aaguid: aaguid,
        credential_id: credential_id,
        public_key_bytes: public_key_bytes
      )
    end
  end

  def initialize(bytes:, relying_party_id_hash:, flags:, sign_count:, aaguid: nil, credential_id:, public_key_bytes:)
    @bytes = bytes
    @relying_party_id_hash = relying_party_id_hash
    @flags = flags
    @sign_count = sign_count
    @aaguid = aaguid
    @credential_id = credential_id
    @public_key_bytes = public_key_bytes
  end

  def user_present?
    flags & USER_PRESENT_FLAG != 0
  end

  def user_verified?
    flags & USER_VERIFIED_FLAG != 0
  end

  # Returns true if the credential is eligible for backup (e.g., synced passkey).
  # This indicates the authenticator supports multi-device credentials.
  def backup_eligible?
    flags & BACKUP_ELIGIBLE_FLAG != 0
  end

  # Returns true if the credential is currently backed up to cloud storage.
  # Only meaningful when +backup_eligible?+ is true.
  def backed_up?
    flags & BACKUP_STATE_FLAG != 0
  end

  def public_key
    @public_key ||= ActionPack::WebAuthn::CoseKey.decode(public_key_bytes).to_openssl_key if public_key_bytes
  end
end
