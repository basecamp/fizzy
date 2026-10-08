require "test_helper"

class SingleSignOn::ProviderTest < ActiveSupport::TestCase
  REDIRECT_URI = "https://fizzy.example.com/session/single_sign_on/callback"

  setup do
    enable_single_sign_on
    stub_single_sign_on_provider
    @provider = SingleSignOn.provider
  end

  teardown do
    disable_single_sign_on
  end

  test "authorization URL" do
    url = URI(authorization_url)

    assert_equal SINGLE_SIGN_ON_AUTHORIZATION_ENDPOINT, "#{url.scheme}://#{url.host}#{url.path}"
    assert_equal({
      "response_type" => "code",
      "client_id" => SINGLE_SIGN_ON_CLIENT_ID,
      "redirect_uri" => REDIRECT_URI,
      "scope" => "openid email profile",
      "state" => "fizzy-state",
      "nonce" => "fizzy-nonce",
      "code_challenge" => "fizzy-challenge",
      "code_challenge_method" => "S256"
    }, Rack::Utils.parse_query(url.query))
  end

  test "authorization URL asks for the groups scope when the provider lists it" do
    stub_single_sign_on_discovery scopes_supported: %w[ openid email profile groups ]

    assert_equal "openid email profile groups", Rack::Utils.parse_query(URI(authorization_url).query)["scope"]
  end

  test "discovery issuer must match the configured issuer" do
    stub_single_sign_on_discovery issuer: "https://other.example.com"

    assert_raises(SingleSignOn::ProviderError) { authorization_url }
  end

  test "discovery must list every endpoint" do
    stub_single_sign_on_discovery token_endpoint: nil

    assert_raises(SingleSignOn::ProviderError) { authorization_url }
  end

  test "discovery endpoints must use https outside development and test" do
    stub_single_sign_on_discovery token_endpoint: "http://id.example.com/token"
    assert_nothing_raised { authorization_url }

    Rails.env.stubs(:local?).returns(false)
    assert_raises(SingleSignOn::ProviderError) { SingleSignOn.provider.authorization_url(**authorization_url_parameters) }
  end

  test "discovery endpoints must be URLs with a host" do
    [ "https:", "https://id example.com/token" ].each do |endpoint|
      stub_single_sign_on_discovery token_endpoint: endpoint
      assert_raises(SingleSignOn::ProviderError, endpoint) { SingleSignOn.provider.authorization_url(**authorization_url_parameters) }
    end
  end

  test "response over the size limit" do
    stub_single_sign_on_discovery padding: "x" * SingleSignOn::Provider::MAX_RESPONSE_SIZE

    error = assert_raises(SingleSignOn::ProviderError) { authorization_url }
    assert_match "more than 1 MB", error.message
  end

  test "unreachable provider" do
    stub_request(:get, "#{SINGLE_SIGN_ON_ISSUER}/.well-known/openid-configuration").to_timeout

    assert_raises(SingleSignOn::ProviderError) { authorization_url }
  end

  test "provider error response" do
    stub_request(:get, "#{SINGLE_SIGN_ON_ISSUER}/.well-known/openid-configuration").to_return(status: 503, body: "")

    assert_raises(SingleSignOn::ProviderError) { authorization_url }
  end

  test "claims for an authorization code" do
    stub_single_sign_on_token_exchange single_sign_on_id_token

    claims = claims_for
    assert_equal "kevin-subject", claims.subject
    assert_requested :post, SINGLE_SIGN_ON_TOKEN_ENDPOINT, body: {
      grant_type: "authorization_code",
      code: "fizzy-code",
      redirect_uri: REDIRECT_URI,
      code_verifier: "fizzy-verifier",
      client_id: SINGLE_SIGN_ON_CLIENT_ID,
      client_secret: "fizzy-secret"
    }
  end

  test "token request uses basic authentication when the provider lists only client_secret_basic" do
    stub_single_sign_on_discovery token_endpoint_auth_methods_supported: %w[ client_secret_basic ]
    stub_single_sign_on_token_exchange single_sign_on_id_token

    assert_equal "kevin-subject", claims_for.subject
    assert_requested :post, SINGLE_SIGN_ON_TOKEN_ENDPOINT,
      headers: { "Authorization" => "Basic #{Base64.strict_encode64("#{SINGLE_SIGN_ON_CLIENT_ID}:fizzy-secret")}" },
      body: { grant_type: "authorization_code", code: "fizzy-code", redirect_uri: REDIRECT_URI, code_verifier: "fizzy-verifier" }
  end

  test "token request uses basic authentication when the discovery document lists no methods" do
    stub_single_sign_on_discovery token_endpoint_auth_methods_supported: nil
    stub_single_sign_on_token_exchange single_sign_on_id_token

    claims_for

    assert_requested :post, SINGLE_SIGN_ON_TOKEN_ENDPOINT,
      headers: { "Authorization" => "Basic #{Base64.strict_encode64("#{SINGLE_SIGN_ON_CLIENT_ID}:fizzy-secret")}" }
  end

  test "basic authentication form-encodes the client secret" do
    enable_single_sign_on client_secret: "se:cret +/"
    @provider = SingleSignOn.provider
    stub_single_sign_on_discovery token_endpoint_auth_methods_supported: %w[ client_secret_basic ]
    stub_single_sign_on_token_exchange single_sign_on_id_token

    claims_for

    assert_requested :post, SINGLE_SIGN_ON_TOKEN_ENDPOINT,
      headers: { "Authorization" => "Basic #{Base64.strict_encode64("#{SINGLE_SIGN_ON_CLIENT_ID}:se%3Acret+%2B%2F")}" }
  end

  test "token request fails when the provider lists neither secret method" do
    stub_single_sign_on_discovery token_endpoint_auth_methods_supported: %w[ private_key_jwt ]

    assert_raises(SingleSignOn::ProviderError) { claims_for }
  end

  test "token response without an ID token" do
    stub_request(:post, SINGLE_SIGN_ON_TOKEN_ENDPOINT).to_return_json(body: { access_token: "access-token" })

    assert_raises(SingleSignOn::ProviderError) { claims_for }
  end

  test "token error response" do
    stub_request(:post, SINGLE_SIGN_ON_TOKEN_ENDPOINT).to_return_json(status: 400, body: { error: "invalid_grant" })

    assert_raises(SingleSignOn::ProviderError) { claims_for }
  end

  test "signing keys leave out encryption keys and unsupported key types" do
    encryption_key = single_sign_on_public_key(OpenSSL::PKey::RSA.generate(2048), kid: "encryption", use: "enc", alg: "RSA-OAEP")
    shared_secret = { kty: "oct", kid: "shared-secret", k: "c2VjcmV0", alg: "HS256" }
    stub_single_sign_on_keys single_sign_on_public_key, encryption_key, shared_secret

    assert_equal [ SINGLE_SIGN_ON_KEY_ID ], @provider.signing_keys.map { |key| key["kid"] }
    assert_equal [ "RS256" ], @provider.signing_algorithms
  end

  test "signing algorithms come from the discovery document when keys have no algorithm" do
    stub_single_sign_on_keys single_sign_on_public_key.except(:alg)
    stub_single_sign_on_discovery id_token_signing_alg_values_supported: %w[ none HS256 ES256 ]

    assert_equal [ "ES256" ], @provider.signing_algorithms
  end

  test "signing algorithms include the discovery document when only some keys have an algorithm" do
    key_without_algorithm = single_sign_on_public_key(OpenSSL::PKey::EC.generate("prime256v1"), kid: "ec-key").except(:alg)
    stub_single_sign_on_keys single_sign_on_public_key, key_without_algorithm
    stub_single_sign_on_discovery id_token_signing_alg_values_supported: %w[ ES256 ]

    assert_equal %w[ RS256 ES256 ], @provider.signing_algorithms
  end

  test "signing algorithms never include none or HMAC" do
    stub_single_sign_on_keys single_sign_on_public_key.except(:alg)
    stub_single_sign_on_discovery id_token_signing_alg_values_supported: %w[ none HS256 ]

    assert_raises(SingleSignOn::ProviderError) { @provider.signing_algorithms }
  end

  private
    def authorization_url
      @provider.authorization_url(**authorization_url_parameters)
    end

    def authorization_url_parameters
      { redirect_uri: REDIRECT_URI, state: "fizzy-state", nonce: "fizzy-nonce", code_challenge: "fizzy-challenge" }
    end

    def claims_for
      @provider.claims_for(code: "fizzy-code", redirect_uri: REDIRECT_URI, code_verifier: "fizzy-verifier", nonce: "fizzy-nonce")
    end
end
