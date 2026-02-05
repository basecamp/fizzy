require "test_helper"

class ActionPack::WebAuthn::Authenticator::AuthenticatorDataTest < ActiveSupport::TestCase
  setup do
    @rp_id_hash = Digest::SHA256.digest("example.com")
    @sign_count = 42
    @aaguid = SecureRandom.random_bytes(16)
    @credential_id = SecureRandom.random_bytes(32)

    # Generate a real EC key for COSE encoding
    ec_key = OpenSSL::PKey::EC.generate("prime256v1")
    public_key_bn = ec_key.public_key.to_bn
    public_key_point = public_key_bn.to_s(2)
    x_coord = public_key_point[1, 32]
    y_coord = public_key_point[33, 32]

    @cose_key = build_cose_key(x_coord, y_coord)
  end

  test "decodes authenticator data without attested credential" do
    flags = 0x01 # user present only
    bytes = build_authenticator_data(flags: flags, include_credential: false)

    data = ActionPack::WebAuthn::Authenticator::AuthenticatorData.decode(bytes)

    assert_equal @rp_id_hash, data.relying_party_id_hash
    assert_equal flags, data.flags
    assert_equal @sign_count, data.sign_count
    assert_nil data.credential_id
    assert_nil data.public_key_bytes
  end

  test "decodes authenticator data with attested credential" do
    flags = 0x41 # user present + attested credential data
    bytes = build_authenticator_data(flags: flags, include_credential: true)

    data = ActionPack::WebAuthn::Authenticator::AuthenticatorData.decode(bytes)

    assert_equal @rp_id_hash, data.relying_party_id_hash
    assert_equal flags, data.flags
    assert_equal @sign_count, data.sign_count
    assert_equal Base64.urlsafe_encode64(@credential_id, padding: false), data.credential_id
    assert_equal @cose_key, data.public_key_bytes
  end

  test "user_present? returns true when flag is set" do
    data = build_data_with_flags(0x01)
    assert data.user_present?
  end

  test "user_present? returns false when flag is not set" do
    data = build_data_with_flags(0x00)
    assert_not data.user_present?
  end

  test "user_verified? returns true when flag is set" do
    data = build_data_with_flags(0x04)
    assert data.user_verified?
  end

  test "user_verified? returns false when flag is not set" do
    data = build_data_with_flags(0x00)
    assert_not data.user_verified?
  end

  test "public_key returns OpenSSL key when public_key_bytes present" do
    flags = 0x41
    bytes = build_authenticator_data(flags: flags, include_credential: true)
    data = ActionPack::WebAuthn::Authenticator::AuthenticatorData.decode(bytes)

    assert_instance_of OpenSSL::PKey::EC, data.public_key
  end

  test "public_key returns nil when public_key_bytes not present" do
    flags = 0x01
    bytes = build_authenticator_data(flags: flags, include_credential: false)
    data = ActionPack::WebAuthn::Authenticator::AuthenticatorData.decode(bytes)

    assert_nil data.public_key
  end

  private
    def build_authenticator_data(flags:, include_credential:)
      bytes = []
      bytes.concat(@rp_id_hash.bytes)
      bytes << flags
      bytes.concat([@sign_count].pack("N").bytes)

      if include_credential
        bytes.concat(@aaguid.bytes)
        bytes.concat([@credential_id.bytesize].pack("n").bytes)
        bytes.concat(@credential_id.bytes)
        bytes.concat(@cose_key.bytes)
      end

      bytes.pack("C*")
    end

    def build_data_with_flags(flags)
      ActionPack::WebAuthn::Authenticator::AuthenticatorData.new(
        relying_party_id_hash: @rp_id_hash,
        flags: flags,
        sign_count: 0,
        credential_id: nil,
        public_key_bytes: nil
      )
    end

    def build_cose_key(x, y)
      # Simple CBOR map for EC2 key
      params = {
        1 => 2,    # kty: EC2
        3 => -7,   # alg: ES256
        -1 => 1,   # crv: P-256
        -2 => x,
        -3 => y
      }
      encode_cbor_map(params)
    end

    def encode_cbor_map(hash)
      bytes = [0xa0 + hash.size]
      hash.each do |key, value|
        bytes.concat(encode_cbor_integer(key))
        bytes.concat(encode_cbor_value(value))
      end
      bytes.pack("C*")
    end

    def encode_cbor_integer(int)
      if int >= 0 && int <= 23
        [int]
      elsif int >= -24 && int < 0
        [0x20 - int - 1]
      else
        raise "Integer encoding not implemented for #{int}"
      end
    end

    def encode_cbor_value(value)
      case value
      when Integer
        encode_cbor_integer(value)
      when String
        length = value.bytesize
        if length <= 23
          [0x40 + length, *value.bytes]
        else
          [0x58, length, *value.bytes]
        end
      end
    end
end
