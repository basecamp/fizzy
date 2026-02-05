require "test_helper"

class ActionPack::WebAuthn::Authenticator::AssertionResponseTest < ActiveSupport::TestCase
  setup do
    @challenge = "test-challenge-123"
    @origin = "https://example.com"
    @client_data_json = {
      challenge: @challenge,
      origin: @origin,
      type: "webauthn.get"
    }.to_json

    # Generate a real key pair for signature verification
    @private_key = OpenSSL::PKey::EC.generate("prime256v1")
    @public_key = @private_key
    @credential = Struct.new(:public_key).new(@public_key)

    @authenticator_data = build_authenticator_data(user_verified: true)
    @signature = sign(@authenticator_data, @client_data_json)

    @response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      client_data_json: @client_data_json,
      authenticator_data: @authenticator_data,
      signature: @signature,
      credential: @credential
    )
  end

  test "initializes with credential, authenticator data, and signature" do
    assert_equal @credential, @response.credential
    assert_equal @authenticator_data, @response.authenticator_data
    assert_equal @signature, @response.signature
  end

  test "validate! succeeds with valid challenge, origin, type, and signature" do
    assert_nothing_raised do
      @response.validate!(challenge: @challenge, origin: @origin)
    end
  end

  test "validate! raises when type is not webauthn.get" do
    client_data_json = {
      challenge: @challenge,
      origin: @origin,
      type: "webauthn.create"
    }.to_json

    response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      client_data_json: client_data_json,
      authenticator_data: @authenticator_data,
      signature: sign(@authenticator_data, client_data_json),
      credential: @credential
    )

    error = assert_raises(ActionPack::WebAuthn::Authenticator::Response::InvalidResponseError) do
      response.validate!(challenge: @challenge, origin: @origin)
    end

    assert_equal "Client data type is not webauthn.get", error.message
  end

  test "validate! raises when signature is invalid" do
    response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      client_data_json: @client_data_json,
      authenticator_data: @authenticator_data,
      signature: "invalid-signature",
      credential: @credential
    )

    error = assert_raises(ActionPack::WebAuthn::Authenticator::Response::InvalidResponseError) do
      response.validate!(challenge: @challenge, origin: @origin)
    end

    assert_equal "Invalid signature", error.message
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

  test "validate! succeeds with user_verification preferred when not verified" do
    authenticator_data = build_authenticator_data(user_verified: false)
    response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      client_data_json: @client_data_json,
      authenticator_data: authenticator_data,
      signature: sign(authenticator_data, @client_data_json),
      credential: @credential
    )

    assert_nothing_raised do
      response.validate!(challenge: @challenge, origin: @origin, user_verification: :preferred)
    end
  end

  test "validate! succeeds with user_verification required when verified" do
    authenticator_data = build_authenticator_data(user_verified: true)
    response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      client_data_json: @client_data_json,
      authenticator_data: authenticator_data,
      signature: sign(authenticator_data, @client_data_json),
      credential: @credential
    )

    assert_nothing_raised do
      response.validate!(challenge: @challenge, origin: @origin, user_verification: :required)
    end
  end

  test "validate! raises with user_verification required when not verified" do
    authenticator_data = build_authenticator_data(user_verified: false)
    response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      client_data_json: @client_data_json,
      authenticator_data: authenticator_data,
      signature: sign(authenticator_data, @client_data_json),
      credential: @credential
    )

    error = assert_raises(ActionPack::WebAuthn::Authenticator::Response::InvalidResponseError) do
      response.validate!(challenge: @challenge, origin: @origin, user_verification: :required)
    end

    assert_equal "User verification is required", error.message
  end

  private
    def build_authenticator_data(user_verified:)
      rp_id_hash = Digest::SHA256.digest("example.com")
      flags = 0x01 # user present
      flags |= 0x04 if user_verified
      sign_count = 0

      bytes = []
      bytes.concat(rp_id_hash.bytes)
      bytes << flags
      bytes.concat([sign_count].pack("N").bytes)
      bytes.pack("C*")
    end

    def sign(authenticator_data, client_data_json)
      client_data_hash = Digest::SHA256.digest(client_data_json)
      signed_data = authenticator_data + client_data_hash
      @private_key.sign("SHA256", signed_data)
    end
end
