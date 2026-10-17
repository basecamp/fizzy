module SingleSignOnTestHelper
  SINGLE_SIGN_ON_ISSUER = "https://id.example.com"
  SINGLE_SIGN_ON_CLIENT_ID = "fizzy"
  SINGLE_SIGN_ON_KEY_ID = "fizzy-test-key"
  SINGLE_SIGN_ON_SIGNING_KEY = OpenSSL::PKey::RSA.generate(2048)

  SINGLE_SIGN_ON_AUTHORIZATION_ENDPOINT = "#{SINGLE_SIGN_ON_ISSUER}/authorize"
  SINGLE_SIGN_ON_TOKEN_ENDPOINT = "#{SINGLE_SIGN_ON_ISSUER}/token"
  SINGLE_SIGN_ON_KEYS_ENDPOINT = "#{SINGLE_SIGN_ON_ISSUER}/keys"

  def enable_single_sign_on(**settings)
    @single_sign_on_settings_before ||= Rails.configuration.x.single_sign_on.dup

    Rails.configuration.x.single_sign_on.merge! \
      issuer: SINGLE_SIGN_ON_ISSUER,
      client_id: SINGLE_SIGN_ON_CLIENT_ID,
      client_secret: "fizzy-secret",
      admin_group: "/fizzy/admin",
      **settings
  end

  def disable_single_sign_on
    if @single_sign_on_settings_before
      Rails.configuration.x.single_sign_on.replace(@single_sign_on_settings_before)
      @single_sign_on_settings_before = nil
    end
  end

  def with_single_sign_on(**settings)
    enable_single_sign_on(**settings)
    yield
  ensure
    disable_single_sign_on
  end

  def stub_single_sign_on_provider
    stub_single_sign_on_discovery
    stub_single_sign_on_keys
  end

  def stub_single_sign_on_discovery(**overrides)
    stub_request(:get, "#{SINGLE_SIGN_ON_ISSUER}/.well-known/openid-configuration")
      .to_return_json(body: single_sign_on_discovery_document.merge(overrides).compact)
  end

  def single_sign_on_discovery_document
    {
      issuer: SINGLE_SIGN_ON_ISSUER,
      authorization_endpoint: SINGLE_SIGN_ON_AUTHORIZATION_ENDPOINT,
      token_endpoint: SINGLE_SIGN_ON_TOKEN_ENDPOINT,
      jwks_uri: SINGLE_SIGN_ON_KEYS_ENDPOINT,
      id_token_signing_alg_values_supported: %w[ RS256 ],
      token_endpoint_auth_methods_supported: %w[ client_secret_basic client_secret_post ]
    }
  end

  def stub_single_sign_on_keys(*keys)
    keys = [ single_sign_on_public_key ] if keys.empty?
    stub_request(:get, SINGLE_SIGN_ON_KEYS_ENDPOINT).to_return_json(body: { keys: keys })
  end

  def single_sign_on_public_key(key = SINGLE_SIGN_ON_SIGNING_KEY, kid: SINGLE_SIGN_ON_KEY_ID, **params)
    JWT::JWK.new(key, { kid: kid, use: "sig", alg: "RS256", **params }).export
  end

  def single_sign_on_id_token(
    key: SINGLE_SIGN_ON_SIGNING_KEY, kid: SINGLE_SIGN_ON_KEY_ID, algorithm: "RS256", **claims
  )
    payload = {
      iss: SINGLE_SIGN_ON_ISSUER,
      aud: SINGLE_SIGN_ON_CLIENT_ID,
      azp: SINGLE_SIGN_ON_CLIENT_ID,
      sub: "kevin-subject",
      email: "kevin@37signals.com",
      email_verified: true,
      name: "Kevin",
      nonce: "fizzy-nonce",
      iat: Time.now.to_i,
      exp: 5.minutes.from_now.to_i
    }

    JWT.encode(payload.merge(claims).compact, key, algorithm, { kid: kid }.compact)
  end

  def stub_single_sign_on_token_exchange(id_token)
    stub_request(:post, SINGLE_SIGN_ON_TOKEN_ENDPOINT)
      .to_return_json(body: { id_token: id_token, access_token: "access-token", token_type: "Bearer" })
  end

  def single_sign_on_claims(**attributes)
    SingleSignOn::Claims.new \
      issuer: SINGLE_SIGN_ON_ISSUER,
      subject: "subject-#{SecureRandom.hex(4)}",
      email_address: "person@example.com",
      email_verified: true,
      name: "Person",
      **attributes
  end

  def sign_in_with_single_sign_on(return_to: nil, **claims)
    untenanted do
      post session_single_sign_on_path, params: { return_to: return_to }.compact
      complete_single_sign_on single_sign_on_authorization_parameters, **claims
    end
  end

  def sign_in_with_single_sign_on_as(identity, groups: [])
    identity = identities(identity) unless identity.is_a?(Identity)
    subject = identity.single_sign_on_link_for(SINGLE_SIGN_ON_ISSUER)&.subject || "#{identity.email_address}-subject"

    stub_single_sign_on_provider
    sign_in_with_single_sign_on sub: subject, email: identity.email_address, groups: groups
    assert_response :redirect, "Single sign-on as #{identity.email_address} did not redirect"
  end

  def complete_single_sign_on(authorization, **claims)
    stub_single_sign_on_token_exchange single_sign_on_id_token(nonce: authorization["nonce"], **claims)
    get session_single_sign_on_callback_path, params: { code: "fizzy-code", state: authorization["state"] }
  end

  def single_sign_on_authorization_parameters
    Rack::Utils.parse_query(URI(response.location).query)
  end

  def current_session
    Session.find_signed(parsed_cookies.signed[:session_token])
  end
end
