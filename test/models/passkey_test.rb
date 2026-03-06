require "test_helper"

class PasskeyTest < ActiveSupport::TestCase
  setup do
    @identity = identities(:kevin)
    @private_key = OpenSSL::PKey::EC.generate("prime256v1")

    ActionPack::WebAuthn::Current.host = "www.example.com"
    ActionPack::WebAuthn::Current.origin = "http://www.example.com"

    @passkey = @identity.passkeys.create!(
      credential_id: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false),
      public_key: @private_key.public_to_der,
      sign_count: 0,
      transports: [ "internal" ]
    )
  end

  test "authenticate with valid assertion" do
    challenge = Passkey.request_options(credentials: [ @passkey ]).challenge
    assertion = build_assertion(challenge: challenge)

    result = @passkey.authenticate(passkey: assertion, challenge: challenge)

    assert_equal @passkey, result
  end

  test "authenticate returns nil with invalid signature" do
    challenge = Passkey.request_options(credentials: [ @passkey ]).challenge
    assertion = build_assertion(challenge: challenge)
    assertion[:signature] = Base64.urlsafe_encode64("invalid", padding: false)

    assert_nil @passkey.authenticate(passkey: assertion, challenge: challenge)
  end

  test "authenticate updates sign count and backed_up" do
    challenge = Passkey.request_options(credentials: [ @passkey ]).challenge
    assertion = build_assertion(challenge: challenge, sign_count: 5, backed_up: true)

    @passkey.authenticate(passkey: assertion, challenge: challenge)

    assert_equal 5, @passkey.reload.sign_count
    assert @passkey.backed_up?
  end

  test "to_public_key_credential" do
    credential = @passkey.to_public_key_credential

    assert_equal @passkey.credential_id, credential.id
    assert_equal @passkey.sign_count, credential.sign_count
    assert_equal @passkey.transports, credential.transports
  end

  test "authenticator lookup by known aaguid" do
    authenticator = Passkey::Authenticator.find_by_aaguid("dd4ec289-e01d-41c9-bb89-70fa845d4bf2")

    assert_equal "Apple Passwords", authenticator.name
  end

  test "authenticator lookup returns nil for unknown aaguid" do
    assert_nil Passkey::Authenticator.find_by_aaguid("00000000-0000-0000-0000-000000000000")
  end

  test "register sets name from authenticator aaguid" do
    passkey = @identity.passkeys.create!(
      credential_id: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false),
      public_key: @private_key.public_to_der,
      sign_count: 0,
      aaguid: "dd4ec289-e01d-41c9-bb89-70fa845d4bf2"
    )

    assert_equal "dd4ec289-e01d-41c9-bb89-70fa845d4bf2", passkey.aaguid
    assert_equal "Apple Passwords", passkey.authenticator.name
  end

  private
    def build_assertion(challenge:, sign_count: 1, backed_up: false)
      origin = ActionPack::WebAuthn::Current.origin

      client_data_json = {
        challenge: challenge,
        origin: origin,
        type: "webauthn.get"
      }.to_json

      authenticator_data = build_authenticator_data(sign_count: sign_count, backed_up: backed_up)
      signature = sign(authenticator_data, client_data_json)

      {
        id: @passkey.credential_id,
        client_data_json: client_data_json,
        authenticator_data: Base64.urlsafe_encode64(authenticator_data, padding: false),
        signature: Base64.urlsafe_encode64(signature, padding: false)
      }
    end

    def build_authenticator_data(sign_count:, backed_up: false)
      rp_id_hash = Digest::SHA256.digest(ActionPack::WebAuthn::Current.host)
      flags = 0x01 | 0x04 # user present + user verified
      flags |= 0x08 | 0x10 if backed_up # backup eligible + backup state

      bytes = []
      bytes.concat(rp_id_hash.bytes)
      bytes << flags
      bytes.concat([ sign_count ].pack("N").bytes)
      bytes.pack("C*")
    end

    def sign(authenticator_data, client_data_json)
      client_data_hash = Digest::SHA256.digest(client_data_json)
      signed_data = authenticator_data + client_data_hash
      @private_key.sign("SHA256", signed_data)
    end
end
