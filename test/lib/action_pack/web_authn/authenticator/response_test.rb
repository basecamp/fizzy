require "test_helper"

class ActionPack::WebAuthn::Authenticator::ResponseTest < ActiveSupport::TestCase
  setup do
    @challenge = "test-challenge-123"
    @origin = "https://example.com"
    @client_data_json = {
      challenge: @challenge,
      origin: @origin,
      type: "webauthn.create"
    }.to_json

    @authenticator_data = build_authenticator_data
    @response = TestableResponse.new(
      client_data_json: @client_data_json,
      authenticator_data: @authenticator_data
    )
  end

  class TestableResponse < ActionPack::WebAuthn::Authenticator::Response
    attr_reader :authenticator_data

    def initialize(authenticator_data:, **attrs)
      super(**attrs)
      @authenticator_data = authenticator_data
    end
  end

  test "parses client data JSON" do
    assert_equal @challenge, @response.client_data["challenge"]
    assert_equal @origin, @response.client_data["origin"]
  end

  test "valid? returns true when challenge and origin match" do
    assert @response.valid?(challenge: @challenge, origin: @origin)
  end

  test "valid? returns false when challenge does not match" do
    assert_not @response.valid?(challenge: "wrong-challenge", origin: @origin)
  end

  test "valid? returns false when origin does not match" do
    assert_not @response.valid?(challenge: @challenge, origin: "https://evil.com")
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

  test "validate! raises when crossOrigin is true" do
    client_data_json = {
      challenge: @challenge,
      origin: @origin,
      type: "webauthn.create",
      crossOrigin: true
    }.to_json

    response = TestableResponse.new(
      client_data_json: client_data_json,
      authenticator_data: @authenticator_data
    )

    error = assert_raises(ActionPack::WebAuthn::Authenticator::Response::InvalidResponseError) do
      response.validate!(challenge: @challenge, origin: @origin)
    end

    assert_equal "Cross-origin requests are not supported", error.message
  end

  test "validate! raises when tokenBinding status is present" do
    client_data_json = {
      challenge: @challenge,
      origin: @origin,
      type: "webauthn.create",
      tokenBinding: { status: "present", id: "some-id" }
    }.to_json

    response = TestableResponse.new(
      client_data_json: client_data_json,
      authenticator_data: @authenticator_data
    )

    error = assert_raises(ActionPack::WebAuthn::Authenticator::Response::InvalidResponseError) do
      response.validate!(challenge: @challenge, origin: @origin)
    end

    assert_equal "Token binding is not supported", error.message
  end

  private
    def build_authenticator_data
      rp_id_hash = Digest::SHA256.digest("example.com")
      flags = 0x05 # user present + user verified
      sign_count = 0

      bytes = []
      bytes.concat(rp_id_hash.bytes)
      bytes << flags
      bytes.concat([sign_count].pack("N").bytes)

      ActionPack::WebAuthn::Authenticator::Data.decode(bytes.pack("C*"))
    end
end
