require "test_helper"

class SingleSignOn::IdTokenTest < ActiveSupport::TestCase
  setup do
    enable_single_sign_on
    stub_single_sign_on_provider
  end

  teardown do
    disable_single_sign_on
  end

  test "valid token" do
    claims = verify(single_sign_on_id_token)

    assert_equal SINGLE_SIGN_ON_ISSUER, claims.issuer
    assert_equal "kevin-subject", claims.subject
    assert_equal "kevin@37signals.com", claims.email_address
    assert claims.email_verified?
    assert_equal "Kevin", claims.name
  end

  test "token signed with another key" do
    assert_invalid single_sign_on_id_token(key: OpenSSL::PKey::RSA.generate(2048))
  end

  test "unsigned token" do
    assert_invalid single_sign_on_id_token(key: nil, algorithm: "none")
  end

  test "HMAC token signed with the public key" do
    assert_invalid single_sign_on_id_token(key: SINGLE_SIGN_ON_SIGNING_KEY.public_key.to_pem, algorithm: "HS256")
  end

  test "token without a key ID" do
    assert_invalid single_sign_on_id_token(kid: nil)
  end

  test "wrong issuer" do
    assert_invalid single_sign_on_id_token(iss: "https://other.example.com")
  end

  test "wrong audience" do
    assert_invalid single_sign_on_id_token(aud: "other-client", azp: "other-client")
  end

  test "several audiences need a matching authorized party" do
    assert_invalid single_sign_on_id_token(aud: [ SINGLE_SIGN_ON_CLIENT_ID, "other-client" ], azp: "other-client")
    assert_invalid single_sign_on_id_token(aud: [ SINGLE_SIGN_ON_CLIENT_ID, "other-client" ], azp: nil)
    assert verify(single_sign_on_id_token(aud: [ SINGLE_SIGN_ON_CLIENT_ID, "other-client" ]))
  end

  test "expired token" do
    assert_invalid single_sign_on_id_token(iat: 10.minutes.ago.to_i, exp: 2.minutes.ago.to_i)
  end

  test "token issued in the future" do
    assert_invalid single_sign_on_id_token(iat: 5.minutes.from_now.to_i)
  end

  test "small clock difference" do
    assert verify(single_sign_on_id_token(iat: 30.seconds.from_now.to_i))
  end

  test "wrong nonce" do
    assert_invalid single_sign_on_id_token(nonce: "other-nonce")
  end

  test "missing nonce" do
    assert_invalid single_sign_on_id_token(nonce: nil)
    assert_invalid single_sign_on_id_token, nonce: nil
  end

  test "missing subject" do
    assert_invalid single_sign_on_id_token(sub: nil)
    assert_invalid single_sign_on_id_token(sub: "")
  end

  test "unknown key ID fetches the keys again once" do
    rotated_key = OpenSSL::PKey::RSA.generate(2048)
    stub_request(:get, SINGLE_SIGN_ON_KEYS_ENDPOINT).to_return_json(
      { body: { keys: [ single_sign_on_public_key ] } },
      { body: { keys: [ single_sign_on_public_key(rotated_key, kid: "rotated-key") ] } })

    assert verify(single_sign_on_id_token(key: rotated_key, kid: "rotated-key"))
    assert_requested :get, SINGLE_SIGN_ON_KEYS_ENDPOINT, times: 2
  end

  test "keys rotated to a new algorithm" do
    rotated_key = OpenSSL::PKey::EC.generate("prime256v1")
    stub_single_sign_on_discovery id_token_signing_alg_values_supported: %w[ RS256 ES256 ]
    stub_request(:get, SINGLE_SIGN_ON_KEYS_ENDPOINT).to_return_json(
      { body: { keys: [ single_sign_on_public_key ] } },
      { body: { keys: [ single_sign_on_public_key(rotated_key, kid: "rotated-key", alg: "ES256") ] } })

    assert verify(single_sign_on_id_token(key: rotated_key, kid: "rotated-key", algorithm: "ES256"))
  end

  test "unknown key ID after the keys are fetched again" do
    assert_invalid single_sign_on_id_token(key: OpenSSL::PKey::RSA.generate(2048), kid: "unknown-key")
    assert_requested :get, SINGLE_SIGN_ON_KEYS_ENDPOINT, times: 2
  end

  private
    def verify(token, nonce: "fizzy-nonce")
      SingleSignOn::IdToken.new(token, provider: SingleSignOn.provider).verify(nonce: nonce)
    end

    def assert_invalid(token, nonce: "fizzy-nonce")
      assert_raises(SingleSignOn::InvalidIdToken) { verify(token, nonce: nonce) }
    end
end
