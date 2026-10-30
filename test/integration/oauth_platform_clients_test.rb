require "test_helper"

# What the connector platforms (Claude, ChatGPT, Cursor, Muse) need of the
# token endpoint and consent: their users share each platform's egress, and
# they ask for offline_access beside the scopes they want.
class OauthPlatformClientsTest < ActionDispatch::IntegrationTest
  CODE_VERIFIER = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
  ADDRESS_BUCKET = "rate-limit:oauth/tokens:127.0.0.1"

  setup do
    @client = oauth_clients(:mcp_client)
    @grant = identities(:david).access_tokens.create!(oauth_client: @client, permission: :write)
  end

  test "offline_access rides along on consent, and the grant is what the other scopes name" do
    sign_in_as :david

    untenanted { get new_oauth_authorization_path, params: consent_params(scope: "read write offline_access") }
    assert_response :success

    untenanted { post oauth_authorization_path, params: consent_params(scope: "read write offline_access") }
    assert_response :redirect
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
    assert code

    redeem code
    assert_response :success
    assert_equal "read write", response.parsed_body["scope"]
    assert response.parsed_body["refresh_token"].present?, "a refresh token, as for every grant"
  end

  test "offline_access alone asks for nothing" do
    sign_in_as :david

    untenanted { get new_oauth_authorization_path, params: consent_params(scope: "offline_access") }
    assert_response :redirect
    assert_equal "invalid_scope", Rack::Utils.parse_query(URI.parse(response.location).query)["error"]
  end

  test "a refresh naming offline_access is weighed without it" do
    refresh @grant.raw_refresh_token, scope: "read write offline_access"
    assert_response :success
    assert_equal "read write", response.parsed_body["scope"]

    refresh response.parsed_body["refresh_token"], scope: "read offline_access"
    assert_response :success
    assert_equal "read", response.parsed_body["scope"], "it may still narrow"

    refresh response.parsed_body["refresh_token"], scope: "offline_access"
    assert_response :bad_request
    assert_equal "invalid_scope", response.parsed_body["error"]
  end

  test "a refresh is charged to its grant, so a full address doesn't stop it" do
    Rails.cache.stubs(:increment).with { |key, *| key == ADDRESS_BUCKET }.returns(1_000)
    Rails.cache.stubs(:increment).with { |key, *| key == grant_bucket(@grant) }.returns(1)

    refresh @grant.raw_refresh_token
    assert_response :success
  end

  test "a grant's own budget holds it" do
    Rails.cache.stubs(:increment).with { |key, *| key == ADDRESS_BUCKET }.returns(1)
    Rails.cache.stubs(:increment).with { |key, *| key == grant_bucket(@grant) }.returns(Oauth::TokensController::GRANT_BUDGET + 1)

    refresh @grant.raw_refresh_token
    assert_response :too_many_requests
  end

  test "a rotated refresh token is charged to its own grant, not the address" do
    presented = @grant.raw_refresh_token
    refresh presented
    assert_response :success

    Rails.cache.stubs(:increment).with { |key, *| key == ADDRESS_BUCKET }.returns(1_000)
    Rails.cache.stubs(:increment).with { |key, *| key == grant_bucket(@grant) }.returns(1)

    travel Oauth::RetiredRefreshToken::GRACE + 1.second
    refresh presented
    assert_response :bad_request, "its replay is judged, not throttled by its neighbors"
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "a code is charged to its client and person, not the address" do
    Rails.cache.stubs(:increment).with { |key, *| key == ADDRESS_BUCKET }.returns(1_000)
    Rails.cache.stubs(:increment).with { |key, *| key == "rate-limit:oauth/tokens:grant:code/#{@client.id}/#{identities(:david).id}" }.returns(1)

    redeem authorization_code_for(identities(:david))
    assert_response :success
  end

  test "what names no grant of its own is held to the address" do
    Rails.cache.stubs(:increment).returns(21)

    {
      "an unknown refresh token" => -> { refresh "fizzy_rt_unknown" },
      "another client's grant" => -> { refresh @grant.raw_refresh_token, client_id: oauth_clients(:trusted_client).client_id },
      "a failed client authentication" => -> { refresh @grant.raw_refresh_token, client_secret: "wrong" },
      "a code issued to another client" => -> { redeem authorization_code_for(identities(:david), client: oauth_clients(:trusted_client)) },
      "a code that doesn't decrypt" => -> { redeem "not-a-code" }
    }.each do |name, request|
      request.call
      assert_response :too_many_requests, name
    end
  end

  test "the address limit counts only what it holds" do
    Rails.cache.stubs(:increment).with { |key, *| key == ADDRESS_BUCKET }.returns(21)
    Rails.cache.stubs(:increment).with { |key, *| key != ADDRESS_BUCKET }.returns(1)

    refresh @grant.raw_refresh_token
    assert_response :success
  end

  private
    def grant_bucket(grant)
      "rate-limit:oauth/tokens:grant:grant/#{grant.id}"
    end

    def refresh(refresh_token, **params)
      untenanted do
        post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id, **params }
      end
    end

    def redeem(code)
      untenanted do
        post oauth_token_path, params: { grant_type: "authorization_code", client_id: @client.client_id, code: code,
          redirect_uri: "http://127.0.0.1:8888/callback", code_verifier: CODE_VERIFIER }
      end
    end

    def consent_params(**overrides)
      {
        client_id: @client.client_id,
        redirect_uri: "http://127.0.0.1:8888/callback",
        response_type: "code",
        code_challenge: code_challenge,
        code_challenge_method: "S256",
        scope: "read",
        state: "xyz123"
      }.merge(overrides)
    end

    def code_challenge
      Base64.urlsafe_encode64(Digest::SHA256.digest(CODE_VERIFIER), padding: false)
    end

    def authorization_code_for(identity, client: @client)
      Oauth::AuthorizationCode.generate \
        client_id: client.client_id,
        identity_id: identity.id,
        code_challenge: code_challenge,
        redirect_uri: "http://127.0.0.1:8888/callback",
        scope: "read write"
    end
end
