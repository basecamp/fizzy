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

    @response = ActionPack::WebAuthn::Authenticator::Response.new(
      client_data_json: @client_data_json
    )
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
end
