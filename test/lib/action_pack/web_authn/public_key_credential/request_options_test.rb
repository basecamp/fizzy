require "test_helper"

class ActionPack::WebAuthn::PublicKeyCredential::RequestOptionsTest < ActiveSupport::TestCase
  setup do
    @relying_party = ActionPack::WebAuthn::RelyingParty.new(id: "example.com", name: "Example App")
    credential = Struct.new(:id, :transports)
    @credentials = [
      credential.new("credential-1", []),
      credential.new("credential-2", [])
    ]
    @options = ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(
      credentials: @credentials,
      relying_party: @relying_party
    )
  end

  test "initializes with required parameters" do
    assert_equal @credentials, @options.credentials
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
    assert_equal "example.com", @options.as_json[:rpId]
    assert_equal [
      { type: "public-key", id: "credential-1" },
      { type: "public-key", id: "credential-2" }
    ], @options.as_json[:allowCredentials]
    assert_equal "preferred", @options.as_json[:userVerification]
  end

  test "as_json includes transports when present" do
    credential = Struct.new(:id, :transports)
    credentials = [
      credential.new("cred-1", [ "usb", "nfc" ]),
      credential.new("cred-2", [ "internal" ])
    ]

    options = ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(
      credentials: credentials,
      relying_party: @relying_party
    )

    assert_equal [
      { type: "public-key", id: "cred-1", transports: [ "usb", "nfc" ] },
      { type: "public-key", id: "cred-2", transports: [ "internal" ] }
    ], options.as_json[:allowCredentials]
  end

  test "as_json omits transports when empty" do
    credential = Struct.new(:id, :transports)
    credentials = [ credential.new("cred-1", []) ]

    options = ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(
      credentials: credentials,
      relying_party: @relying_party
    )

    assert_equal [
      { type: "public-key", id: "cred-1" }
    ], options.as_json[:allowCredentials]
  end
end
