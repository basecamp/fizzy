require "test_helper"

class Oauth::AuthorizationCodeTest < ActiveSupport::TestCase
  test "generate creates encrypted code" do
    code = Oauth::AuthorizationCode.generate \
      client_id: "test_client",
      identity_id: 123,
      code_challenge: "abc123",
      redirect_uri: "http://127.0.0.1:8888/callback",
      scope: "read"

    assert_kind_of String, code
    assert code.length > 50, "Encrypted code should be reasonably long"
  end

  test "parse decrypts valid code" do
    code = Oauth::AuthorizationCode.generate \
      client_id: "test_client",
      identity_id: 456,
      code_challenge: "challenge_hash",
      redirect_uri: "http://127.0.0.1:8888/callback",
      scope: "read write"

    parsed = Oauth::AuthorizationCode.parse(code)

    assert_not_nil parsed
    assert_equal "test_client", parsed.client_id
    assert_equal 456, parsed.identity_id
    assert_equal "challenge_hash", parsed.code_challenge
    assert_equal "http://127.0.0.1:8888/callback", parsed.redirect_uri
    assert_equal "read write", parsed.scope
  end

  test "parse returns nil for blank code" do
    assert_nil Oauth::AuthorizationCode.parse("")
    assert_nil Oauth::AuthorizationCode.parse(nil)
  end

  test "parse returns nil for invalid code" do
    assert_nil Oauth::AuthorizationCode.parse("garbage_data_here")
  end

  test "parse returns nil for tampered code" do
    code = Oauth::AuthorizationCode.generate \
      client_id: "test_client",
      identity_id: 123,
      code_challenge: "abc",
      redirect_uri: "http://127.0.0.1/cb",
      scope: "read"

    tampered = code[0...-10] + "XXXXXXXXXX"
    assert_nil Oauth::AuthorizationCode.parse(tampered)
  end

  test "parse returns nil for expired code" do
    code = Oauth::AuthorizationCode.generate \
      client_id: "test_client",
      identity_id: 123,
      code_challenge: "abc",
      redirect_uri: "http://127.0.0.1/cb",
      scope: "read"

    travel 65.seconds do
      assert_nil Oauth::AuthorizationCode.parse(code)
    end
  end

  test "code is valid within 60 second window" do
    code = Oauth::AuthorizationCode.generate \
      client_id: "test_client",
      identity_id: 123,
      code_challenge: "abc",
      redirect_uri: "http://127.0.0.1/cb",
      scope: "read"

    travel 55.seconds do
      parsed = Oauth::AuthorizationCode.parse(code)
      assert_not_nil parsed
      assert_equal "test_client", parsed.client_id
    end
  end

  test "valid_pkce? returns true for correct S256 verifier" do
    code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

    details = Oauth::AuthorizationCode::Details.new \
      client_id: "test",
      identity_id: 1,
      code_challenge: code_challenge,
      redirect_uri: "http://127.0.0.1/cb",
      scope: "read"

    assert Oauth::AuthorizationCode.valid_pkce?(details, code_verifier)
  end

  test "valid_pkce? returns false for wrong verifier" do
    code_verifier = "correct_verifier"
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

    details = Oauth::AuthorizationCode::Details.new \
      client_id: "test",
      identity_id: 1,
      code_challenge: code_challenge,
      redirect_uri: "http://127.0.0.1/cb",
      scope: "read"

    assert_not Oauth::AuthorizationCode.valid_pkce?(details, "wrong_verifier")
  end

  test "valid_pkce? returns false for nil code details" do
    assert_not Oauth::AuthorizationCode.valid_pkce?(nil, "verifier")
  end

  test "valid_pkce? returns false for blank verifier" do
    details = Oauth::AuthorizationCode::Details.new \
      client_id: "test",
      identity_id: 1,
      code_challenge: "challenge",
      redirect_uri: "http://127.0.0.1/cb",
      scope: "read"

    assert_not Oauth::AuthorizationCode.valid_pkce?(details, "")
    assert_not Oauth::AuthorizationCode.valid_pkce?(details, nil)
  end

  test "auth code details are immutable" do
    details = Oauth::AuthorizationCode::Details.new \
      client_id: "test",
      identity_id: 1,
      code_challenge: "challenge",
      redirect_uri: "http://127.0.0.1/cb",
      scope: "read"

    assert_raises(FrozenError) { details.instance_variable_set(:@client_id, "hacked") }
  end
end
