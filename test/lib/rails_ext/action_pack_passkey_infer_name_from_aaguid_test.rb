require "test_helper"

class ActionPackPasskeyInferNameFromAaguidTest < ActiveSupport::TestCase
  setup do
    @identity = identities(:kevin)
    @private_key = OpenSSL::PKey::EC.generate("prime256v1")

    ActionPack::WebAuthn::Current.host = "www.example.com"
    ActionPack::WebAuthn::Current.origin = "http://www.example.com"
  end

  test "authenticator lookup by known aaguid" do
    authenticator = Passkey::Authenticator.find_by_aaguid("dd4ec289-e01d-41c9-bb89-70fa845d4bf2")

    assert_equal "Apple Passwords", authenticator.name
  end

  test "authenticator lookup returns nil for unknown aaguid" do
    assert_nil Passkey::Authenticator.find_by_aaguid("00000000-0000-0000-0000-000000000000")
  end

  test "authenticator lookup by aaguid on passkey" do
    passkey = @identity.passkeys.create!(
      credential_id: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false),
      public_key: @private_key.public_to_der,
      sign_count: 0,
      aaguid: "dd4ec289-e01d-41c9-bb89-70fa845d4bf2"
    )

    assert_equal "Apple Passwords", passkey.authenticator.name
  end
end
