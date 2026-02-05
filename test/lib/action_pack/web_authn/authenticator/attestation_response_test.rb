require "test_helper"

class ActionPack::WebAuthn::Authenticator::AttestationResponseTest < ActiveSupport::TestCase
  setup do
    @challenge = "test-challenge-123"
    @origin = "https://example.com"
    @client_data_json = {
      challenge: @challenge,
      origin: @origin,
      type: "webauthn.create"
    }.to_json

    @response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: @client_data_json,
      attestation_object: build_attestation_object(user_verified: true)
    )
  end

  test "initializes with attestation object" do
    assert_not_nil @response.attestation_object
  end

  test "validate! succeeds with valid challenge, origin, and type" do
    assert_nothing_raised do
      @response.validate!(challenge: @challenge, origin: @origin)
    end
  end

  test "validate! succeeds with user_verification preferred when not verified" do
    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: @client_data_json,
      attestation_object: build_attestation_object(user_verified: false)
    )

    assert_nothing_raised do
      response.validate!(challenge: @challenge, origin: @origin, user_verification: :preferred)
    end
  end

  test "validate! succeeds with user_verification required when verified" do
    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: @client_data_json,
      attestation_object: build_attestation_object(user_verified: true)
    )

    assert_nothing_raised do
      response.validate!(challenge: @challenge, origin: @origin, user_verification: :required)
    end
  end

  test "validate! raises with user_verification required when not verified" do
    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: @client_data_json,
      attestation_object: build_attestation_object(user_verified: false)
    )

    error = assert_raises(ActionPack::WebAuthn::Authenticator::Response::InvalidResponseError) do
      response.validate!(challenge: @challenge, origin: @origin, user_verification: :required)
    end

    assert_equal "User verification is required", error.message
  end

  test "validate! raises when type is not webauthn.create" do
    client_data_json = {
      challenge: @challenge,
      origin: @origin,
      type: "webauthn.get"
    }.to_json

    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: client_data_json,
      attestation_object: build_attestation_object(user_verified: true)
    )

    error = assert_raises(ActionPack::WebAuthn::Authenticator::Response::InvalidResponseError) do
      response.validate!(challenge: @challenge, origin: @origin)
    end

    assert_equal "Client data type is not webauthn.create", error.message
  end

  test "validate! raises when challenge does not match" do
    error = assert_raises(ActionPack::WebAuthn::Authenticator::Response::InvalidResponseError) do
      @response.validate!(challenge: "wrong-challenge", origin: @origin)
    end

    assert_equal "Challenge does not match", error.message
  end

  test "validate! raises when origin does not match" do
    error = assert_raises(ActionPack::WebAuthn::Authenticator::Response::InvalidResponseError) do
      @response.validate!(challenge: @challenge, origin: "https://evil.com")
    end

    assert_equal "Origin does not match", error.message
  end

  test "validate! raises when attestation format is not supported" do
    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: @client_data_json,
      attestation_object: build_attestation_object(user_verified: true, format: "packed")
    )

    error = assert_raises(ActionPack::WebAuthn::Authenticator::Response::InvalidResponseError) do
      response.validate!(challenge: @challenge, origin: @origin)
    end

    assert_equal "Unsupported attestation format: packed", error.message
  end

  private
    def build_attestation_object(user_verified:, format: "none")
      auth_data = build_authenticator_data(user_verified: user_verified)
      encode_cbor_attestation_object(auth_data, format: format)
    end

    def build_authenticator_data(user_verified:)
      rp_id_hash = Digest::SHA256.digest("example.com")
      flags = 0x41 # user present + attested credential
      flags |= 0x04 if user_verified
      sign_count = 0
      aaguid = SecureRandom.random_bytes(16)
      credential_id = SecureRandom.random_bytes(32)
      cose_key = build_cose_key

      bytes = []
      bytes.concat(rp_id_hash.bytes)
      bytes << flags
      bytes.concat([sign_count].pack("N").bytes)
      bytes.concat(aaguid.bytes)
      bytes.concat([credential_id.bytesize].pack("n").bytes)
      bytes.concat(credential_id.bytes)
      bytes.concat(cose_key.bytes)
      bytes.pack("C*")
    end

    def build_cose_key
      ec_key = OpenSSL::PKey::EC.generate("prime256v1")
      public_key_bn = ec_key.public_key.to_bn
      public_key_point = public_key_bn.to_s(2)
      x = public_key_point[1, 32]
      y = public_key_point[33, 32]

      params = { 1 => 2, 3 => -7, -1 => 1, -2 => x, -3 => y }
      encode_cbor_map(params)
    end

    def encode_cbor_attestation_object(auth_data, format:)
      bytes = [0xa3]
      bytes.concat([0x63, *"fmt".bytes])
      bytes.concat([0x40 + format.bytesize, *format.bytes])
      bytes.concat([0x67, *"attStmt".bytes])
      bytes << 0xa0
      bytes.concat([0x68, *"authData".bytes])
      if auth_data.bytesize <= 255
        bytes.concat([0x58, auth_data.bytesize])
      else
        bytes.concat([0x59, (auth_data.bytesize >> 8) & 0xff, auth_data.bytesize & 0xff])
      end
      bytes.concat(auth_data.bytes)
      bytes.pack("C*")
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
        length <= 23 ? [0x40 + length, *value.bytes] : [0x58, length, *value.bytes]
      end
    end
end
