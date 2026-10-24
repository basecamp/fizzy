require "test_helper"

class TokenDigesterTest < ActiveSupport::TestCase
  # HMAC-SHA256 with key "key", the standard published vector. bc3's
  # Oauth::TokenDigester is OpenSSL::HMAC.hexdigest("SHA256", pepper, raw), so
  # matching it here keeps the two byte-compatible.
  test "a digest is lowercase hex HMAC-SHA256 under the pepper, as in bc3" do
    with_peppers 1 => "key" do
      assert_equal "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8",
        TokenDigester.digest("The quick brown fox jumps over the lazy dog")
    end
  end

  test "a version 1 digest is bare; later versions carry their number" do
    with_peppers 1 => "a" * 32, 2 => "b" * 32 do
      assert_match(/\A\h{64}\z/, TokenDigester.digest("raw"))
      assert_match(/\A2\$\h{64}\z/, TokenDigester.digest("raw", version: 2))
      assert_equal [ TokenDigester.digest("raw"), TokenDigester.digest("raw", version: 2) ], TokenDigester.digests("raw")
    end
  end

  test "verify checks a digest under the pepper its version names" do
    with_peppers 1 => "a" * 32, 2 => "b" * 32 do
      assert TokenDigester.verify("raw", TokenDigester.digest("raw"))
      assert TokenDigester.verify("raw", TokenDigester.digest("raw", version: 2))

      assert_not TokenDigester.verify("other", TokenDigester.digest("raw"))
      assert_not TokenDigester.verify("raw", "3$" + TokenDigester.digest("raw"))
      assert_not TokenDigester.verify("raw", "x$" + TokenDigester.digest("raw"))
      assert_not TokenDigester.verify("", TokenDigester.digest(""))
      assert_not TokenDigester.verify(nil, TokenDigester.digest("raw"))
      assert_not TokenDigester.verify([ "raw" ], TokenDigester.digest("raw"))
      assert_not TokenDigester.verify("raw", nil)
    end
  end

  test "a configured pepper is used as given" do
    assert_equal "p" * 40, TokenDigester.send(:configured_pepper, "p" * 40, required: true)
  end

  # The deploy configs and the self-hosting docs name OAUTH_TOKEN_PEPPER;
  # reading any other variable would quietly fall back to the derived pepper.
  test "the pepper is read from OAUTH_TOKEN_PEPPER" do
    with_peppers nil do
      with_env "OAUTH_TOKEN_PEPPER" => "e" * 40 do
        assert_equal OpenSSL::HMAC.hexdigest("SHA256", "e" * 40, "raw"), TokenDigester.digest("raw")
      end
    end
  end

  test "a deployment that requires a pepper refuses to run without one" do
    assert_raises(TokenDigester::MissingPepper) { TokenDigester.send(:configured_pepper, nil, required: true) }
    assert_raises(TokenDigester::MissingPepper) { TokenDigester.send(:configured_pepper, "", required: true) }
  end

  test "a short pepper is refused" do
    assert_raises(TokenDigester::MissingPepper) { TokenDigester.send(:configured_pepper, "short", required: false) }
  end

  test "without a pepper, one is derived from secret_key_base" do
    assert_equal Rails.application.key_generator.generate_key("token_digest_pepper", 32),
      TokenDigester.send(:configured_pepper, nil, required: false)
  end

  test "SaaS deployments require a pepper; development, test and self-hosted installs don't" do
    Fizzy.stubs(:saas?).returns(true)
    assert_not TokenDigester.pepper_required?

    %w[ beta staging production ].each do |env|
      Rails.stubs(:env).returns(ActiveSupport::EnvironmentInquirer.new(env))
      assert TokenDigester.pepper_required?, env
    end

    Fizzy.stubs(:saas?).returns(false)
    assert_not TokenDigester.pepper_required?
  end

  private
    def with_peppers(peppers)
      original = TokenDigester.instance_variable_get(:@peppers)
      TokenDigester.instance_variable_set(:@peppers, peppers)
      yield
    ensure
      TokenDigester.instance_variable_set(:@peppers, original)
    end

    def with_env(values)
      original = values.keys.index_with { |key| ENV[key] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      original.each { |key, value| ENV[key] = value }
    end
end
