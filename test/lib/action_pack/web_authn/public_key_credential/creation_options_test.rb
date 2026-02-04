require "test_helper"

class ActionPack::WebAuthn::PublicKeyCredential::CreationOptionsTest < ActiveSupport::TestCase
  setup do
    @relying_party = ActionPack::WebAuthn::RelyingParty.new(id: "example.com", name: "Example App")
    @options = ActionPack::WebAuthn::PublicKeyCredential::CreationOptions.new(
      id: "user-123",
      name: "user@example.com",
      display_name: "Test User",
      relying_party: @relying_party
    )
  end

  test "initializes with required parameters" do
    assert_equal "user-123", @options.id
    assert_equal "user@example.com", @options.name
    assert_equal "Test User", @options.display_name
    assert_equal @relying_party, @options.relying_party
  end

  test "generates base64url encoded challenge" do
    assert_match(/\A[A-Za-z0-9_-]+\z/, @options.challenge)
  end

  test "generates challenge of correct length" do
    decoded = Base64.urlsafe_decode64(@options.challenge)
    assert_equal 32, decoded.bytesize
  end

  test "as_json" do
    assert_equal @options.challenge, @options.as_json[:challenge]

    assert_equal({ id: "example.com", name: "Example App" }, @options.as_json[:rp])

    user = @options.as_json[:user]
    assert_equal Base64.urlsafe_encode64("user-123", padding: false), user[:id]
    assert_equal "user@example.com", user[:name]
    assert_equal "Test User", user[:displayName]

    assert_equal [
      { type: "public-key", alg: -7 },
      { type: "public-key", alg: -257 }
    ], @options.as_json[:pubKeyCredParams]

    assert_equal({ userVerification: "preferred" }, @options.as_json[:authenticatorSelection])
  end
end
