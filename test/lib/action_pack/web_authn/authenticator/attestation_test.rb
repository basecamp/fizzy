require "test_helper"

class ActionPack::WebAuthn::Authenticator::AttestationTest < ActiveSupport::TestCase
  setup do
    @rp_id_hash = Digest::SHA256.digest("example.com")
    @sign_count = 42
    @aaguid = SecureRandom.random_bytes(16)
    @credential_id = SecureRandom.random_bytes(32)

    # Generate a real EC key
    ec_key = OpenSSL::PKey::EC.generate("prime256v1")
    public_key_bn = ec_key.public_key.to_bn
    public_key_point = public_key_bn.to_s(2)
    x_coord = public_key_point[1, 32]
    y_coord = public_key_point[33, 32]

    @cose_key = build_cose_key(x_coord, y_coord)
    @auth_data = build_authenticator_data
    @attestation_object = build_attestation_object
  end

  test "decodes attestation object" do
    attestation = ActionPack::WebAuthn::Authenticator::Attestation.decode(@attestation_object)

    assert_equal "none", attestation.format
    assert_equal({}, attestation.attestation_statement)
    assert_instance_of ActionPack::WebAuthn::Authenticator::AuthenticatorData, attestation.authenticator_data
  end

  test "delegates credential_id to authenticator_data" do
    attestation = ActionPack::WebAuthn::Authenticator::Attestation.decode(@attestation_object)

    assert_equal Base64.urlsafe_encode64(@credential_id, padding: false), attestation.credential_id
  end

  test "delegates sign_count to authenticator_data" do
    attestation = ActionPack::WebAuthn::Authenticator::Attestation.decode(@attestation_object)

    assert_equal @sign_count, attestation.sign_count
  end

  test "delegates public_key to authenticator_data" do
    attestation = ActionPack::WebAuthn::Authenticator::Attestation.decode(@attestation_object)

    assert_instance_of OpenSSL::PKey::EC, attestation.public_key
  end

  private
    def build_authenticator_data
      bytes = []
      bytes.concat(@rp_id_hash.bytes)
      bytes << 0x41 # flags: user present + attested credential
      bytes.concat([@sign_count].pack("N").bytes)
      bytes.concat(@aaguid.bytes)
      bytes.concat([@credential_id.bytesize].pack("n").bytes)
      bytes.concat(@credential_id.bytes)
      bytes.concat(@cose_key.bytes)
      bytes.pack("C*")
    end

    def build_attestation_object
      # CBOR map: { "fmt": "none", "attStmt": {}, "authData": <bytes> }
      encode_cbor_attestation_object
    end

    def encode_cbor_attestation_object
      bytes = [0xa3] # map with 3 items

      # "fmt" => "none"
      bytes.concat([0x63, *"fmt".bytes]) # text string "fmt"
      bytes.concat([0x64, *"none".bytes]) # text string "none"

      # "attStmt" => {}
      bytes.concat([0x67, *"attStmt".bytes]) # text string "attStmt"
      bytes << 0xa0 # empty map

      # "authData" => <bytes>
      bytes.concat([0x68, *"authData".bytes]) # text string "authData"
      auth_data_length = @auth_data.bytesize
      if auth_data_length <= 23
        bytes << (0x40 + auth_data_length)
      elsif auth_data_length <= 255
        bytes.concat([0x58, auth_data_length])
      else
        bytes.concat([0x59, (auth_data_length >> 8) & 0xff, auth_data_length & 0xff])
      end
      bytes.concat(@auth_data.bytes)

      bytes.pack("C*")
    end

    def build_cose_key(x, y)
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
