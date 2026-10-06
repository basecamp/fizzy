require "test_helper"

# client_secret_basic beside client_secret_post (RFC 6749 §2.3.1).
class OauthClientSecretBasicTest < ActionDispatch::IntegrationTest
  include OauthAvailabilityTestHelper, OauthClientCredentialsTestHelper

  CODE_VERIFIER = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

  setup do
    @client = oauth_clients(:confidential_client)
    @secret = "confidential_secret_789"
  end

  # client_secret_basic at the token endpoint

  test "a confidential client refreshes with HTTP Basic alone" do
    token = grant_for(@client)

    refresh token, headers: basic(@client.client_id, @secret)

    assert_response :success
    assert_not_equal token.refresh_token, token.reload.refresh_token
    assert_equal token.refresh_token, response.parsed_body["refresh_token"]
  end

  test "a confidential client redeems a code with HTTP Basic alone" do
    code = authorization_code_for(@client)

    assert_difference "Identity::AccessToken.count", +1 do
      untenanted do
        post oauth_token_path, params: { grant_type: "authorization_code", code: code,
          redirect_uri: "https://connector.example.com/callback", code_verifier: CODE_VERIFIER },
          headers: basic(@client.client_id, @secret)
      end
    end

    assert_response :success
  end

  test "Basic credentials are form-urlencoded before they are encoded, so %3A and + decode after the split" do
    client = Oauth::Client.create! name: "Colon", redirect_uris: %w[ https://connector.example.com/callback ],
      token_endpoint_auth_method: "client_secret_basic", client_secret: "pa:ss word+"
    token = grant_for(client)

    refresh token, headers: basic(client.client_id, "pa:ss word+")

    assert_response :success
  end

  test "Basic beside a body client_id naming the same client authenticates" do
    token = grant_for(@client)

    refresh token, params: { client_id: @client.client_id }, headers: basic(@client.client_id, @secret)

    assert_response :success
  end

  test "Basic beside an empty body client_secret authenticates" do
    token = grant_for(@client)

    refresh token, params: { client_secret: "" }, headers: basic(@client.client_id, @secret)

    assert_response :success
  end

  test "Basic and a body client_secret together are two methods, refused as invalid_request" do
    token = grant_for(@client)

    [ @secret, "something-else" ].each do |body_secret|
      refresh token, params: { client_id: @client.client_id, client_secret: body_secret }, headers: basic(@client.client_id, @secret)

      assert_response :bad_request
      assert_equal "invalid_request", response.parsed_body["error"]
    end

    assert_equal token.refresh_token, token.reload.refresh_token
  end

  test "Basic naming one client while the body names another fails as invalid_client" do
    token = grant_for(@client)

    refresh token, params: { client_id: oauth_clients(:mcp_client).client_id }, headers: basic(@client.client_id, @secret)

    assert_client_authentication_failed
    assert_equal token.refresh_token, token.reload.refresh_token
  end

  test "a malformed Basic header fails as invalid_client" do
    token = grant_for(@client)

    [ "Basic not-base64!", "Basic #{Base64.strict_encode64("no-colon")}", "Basic #{Base64.strict_encode64(":#{@secret}")}",
      "Basic #{Base64.strict_encode64("#{@client.client_id}:%ZZ")}", "Basic #{Base64.strict_encode64("#{@client.client_id}:%FF")}" ].each do |header|
      refresh token, headers: { "Authorization" => header }

      assert_client_authentication_failed header
    end

    assert_equal token.refresh_token, token.reload.refresh_token
  end

  test "Basic naming a public client fails: a public client holds no password" do
    client = oauth_clients(:mcp_client)
    token = grant_for(client)

    [ "", "anything" ].each do |secret|
      refresh token, headers: basic(client.client_id, secret)

      assert_client_authentication_failed
    end

    assert_equal token.refresh_token, token.reload.refresh_token
  end

  test "a wrong Basic secret and an unknown Basic client get the same 401 and Basic challenge" do
    token = grant_for(@client)

    refresh token, headers: basic(@client.client_id, "wrong")
    wrong_secret = [ response.status, response.parsed_body, response.headers["WWW-Authenticate"] ]

    refresh token, headers: basic("no-such-client", "wrong")
    unknown_client = [ response.status, response.parsed_body, response.headers["WWW-Authenticate"] ]

    assert_client_authentication_failed
    assert_equal wrong_secret, unknown_client
    assert_equal token.refresh_token, token.reload.refresh_token
  end

  test "a failed client_secret_post authentication is a 401 with no challenge, since the client never tried the header" do
    token = grant_for(@client)

    [ { client_id: @client.client_id, client_secret: "wrong" }, { client_id: @client.client_id } ].each do |params|
      refresh token, params: params

      assert_client_authentication_failed params.inspect, challenged: false
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "a failed client_secret_post beside an Authorization header of another scheme names Basic" do
    token = grant_for(@client)

    refresh token, params: { client_id: @client.client_id, client_secret: "wrong" }, headers: { "Authorization" => "Bearer #{token.token}" }

    assert_client_authentication_failed
  end

  test "the pilot gate reads the client a Basic header names" do
    token = grant_for(@client)

    with_oauth_availability acceptance: false, issuance: false, pilot_client_ids: [ @client.client_id ] do
      refresh token, headers: basic(@client.client_id, @secret)
    end

    assert_response :success
  end

  test "every advertised secret method authenticates at the token endpoint" do
    untenanted { get "/.well-known/oauth-authorization-server" }
    methods = response.parsed_body["token_endpoint_auth_methods_supported"]

    assert_equal %w[ none client_secret_post client_secret_basic ], methods

    { "client_secret_post" => [ { client_id: @client.client_id, client_secret: @secret }, {} ],
      "client_secret_basic" => [ {}, basic(@client.client_id, @secret) ] }.each do |method, (params, headers)|
      refresh grant_for(@client), params: params, headers: headers

      assert_response :success, method
    end
  end

  test "DCR registers a client_secret_basic client as confidential" do
    untenanted do
      post oauth_clients_path, params: { client_name: "Basic Connector", redirect_uris: %w[ https://connector.example.com/callback ],
        token_endpoint_auth_method: "client_secret_basic" }, as: :json
    end

    assert_response :created
    assert_equal "client_secret_basic", response.parsed_body["token_endpoint_auth_method"]
    assert_not_nil response.parsed_body["client_secret"]
    assert Oauth::Client.find_by(client_id: response.parsed_body["client_id"]).confidential?
  end

  private
    def grant_for(client)
      identities(:david).access_tokens.create!(oauth_client: client, permission: :read)
    end

    def refresh(token, params: nil, headers: {})
      params ||= headers.key?("Authorization") ? {} : { client_id: token.oauth_client.client_id }
      untenanted do
        post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: token.refresh_token }.merge(params), headers: headers
      end
    end

    def authorization_code_for(client)
      Oauth::AuthorizationCode.generate \
        client_id: client.client_id,
        identity_id: identities(:david).id,
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(CODE_VERIFIER), padding: false),
        redirect_uri: "https://connector.example.com/callback",
        scope: "read"
    end
end
