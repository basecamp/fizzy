require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  include OauthAvailabilityTestHelper

  setup do
    @davids_bearer_token = bearer_token_env(identity_access_tokens(:davids_api_token).token)
    @jasons_bearer_token = bearer_token_env(identity_access_tokens(:jasons_api_token).token)
  end

  test "authenticate with user credentials" do
    identity = identities(:david)

    untenanted do
      post session_path(format: :json), params: { email_address: identity.email_address }
      assert_response :created
      pending_token = @response.parsed_body["pending_authentication_token"]
      assert pending_token.present?

      magic_link = MagicLink.last
      post session_magic_link_path(format: :json), params: { code: magic_link.code, pending_authentication_token: pending_token }
      assert_response :success
      assert @response.parsed_body["session_token"].present?
    end
  end

  test "logout with user credentials" do
    identity = identities(:david)

    untenanted do
      post session_path(format: :json), params: { email_address: identity.email_address }
      magic_link = MagicLink.last

      assert_difference -> { identity.sessions.count }, +1 do
        post session_magic_link_path(format: :json), params: { code: magic_link.code, pending_authentication_token: @response.parsed_body["pending_authentication_token"] }
      end
      assert cookies[:session_token].present?

      assert_difference -> { identity.sessions.count }, -1 do
        delete session_path(format: :json)
      end
      assert_response :no_content
      assert_not cookies[:session_token].present?
    end
  end

  test "authenticate with valid access token" do
    get boards_path(format: :json), env: @davids_bearer_token
    assert_response :success
  end

  test "fail to authenticate with invalid access token" do
    get boards_path(format: :json), env: bearer_token_env("nonsense")

    assert_response :unauthorized
    assert_bearer_challenge error: "invalid_token"
  end

  test "an expired access token is challenged as invalid_token so the client refreshes" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client), permission: :write)

    travel Identity::AccessToken::EXPIRES_IN + 1.second do
      get boards_path(format: :json), env: bearer_token_env(token.token)
    end

    assert_response :unauthorized
    assert_bearer_challenge error: "invalid_token"
  end

  test "an OAuth token is challenged as invalid_token while OAuth is dark" do
    token = identities(:david).access_tokens.create!(oauth_client: oauth_clients(:mcp_client), permission: :write)

    with_oauth_availability acceptance: false do
      get boards_path(format: :json), env: bearer_token_env(token.token)
    end

    assert_response :unauthorized
    assert_match 'error="invalid_token"', response.headers["WWW-Authenticate"]
    assert_no_match "resource_metadata", response.headers["WWW-Authenticate"]
  end

  test "changing data requires a write-endowed access token" do
    post boards_path(format: :json), params: { board: { name: "My new board" } }, env: @jasons_bearer_token
    assert_response :forbidden
    assert_bearer_challenge error: "insufficient_scope"
    assert_match 'scope="write"', response.headers["WWW-Authenticate"]

    post boards_path(format: :json), params: { board: { name: "My new board" } }, env: @davids_bearer_token
    assert_response :success
  end

  test "a read-only token still reads" do
    get boards_path(format: :json), env: @jasons_bearer_token
    assert_response :success
  end

  test "an expired read-only token on a write is invalid_token, not insufficient_scope" do
    token = identities(:jason).access_tokens.create!(oauth_client: oauth_clients(:mcp_client), permission: :read)

    travel Identity::AccessToken::EXPIRES_IN + 1.second do
      post boards_path(format: :json), params: { board: { name: "My new board" } }, env: bearer_token_env(token.token)
    end

    assert_response :unauthorized
    assert_bearer_challenge error: "invalid_token"
  end

  test "a JSON request without credentials is challenged instead of redirected to sign in" do
    get boards_path(format: :json)

    assert_response :unauthorized
    assert_bearer_challenge
    assert_no_match "error=", response.headers["WWW-Authenticate"]
  end

  test "the challenge names protected resource metadata that resolves" do
    get boards_path(format: :json)
    metadata_url = response.headers["WWW-Authenticate"][/resource_metadata="([^"]+)"/, 1]

    get URI(metadata_url).request_uri
    assert_response :success
    assert_equal "http://www.example.com/", response.parsed_body["resource"]
  end

  test "the challenge leaves out resource metadata while OAuth is dark" do
    with_oauth_availability acceptance: false do
      get boards_path(format: :json)
    end

    assert_response :unauthorized
    assert_match(/\ABearer realm="Application"\z/, response.headers["WWW-Authenticate"])
  end

  test "a JSON request from our own pages without a session still goes to sign in" do
    get boards_path(format: :json), xhr: true
    assert_response :redirect

    cookies[:session_token] = "stale"
    get boards_path(format: :json)
    assert_response :redirect
  end

  test "an HTML request without credentials still goes to sign in" do
    get boards_path
    assert_response :redirect
  end

  test "the bearer scheme is matched case-insensitively" do
    get boards_path(format: :json), env: { "HTTP_AUTHORIZATION" => "bearer #{identity_access_tokens(:davids_api_token).token}" }
    assert_response :success

    get boards_path(format: :json), env: { "HTTP_AUTHORIZATION" => "BEARER nonsense" }
    assert_response :unauthorized
    assert_bearer_challenge error: "invalid_token"
  end

  test "Bearer elsewhere in another scheme's credentials is not bearer authentication" do
    get boards_path(format: :json), env: { "HTTP_AUTHORIZATION" => "Basic Bearer #{identity_access_tokens(:davids_api_token).token}" }

    assert_response :unauthorized
    assert_no_match "error=", response.headers["WWW-Authenticate"]
  end

  test "a bearer token on an HTML request is refused with a Bearer challenge" do
    get boards_path, env: @davids_bearer_token

    assert_response :unauthorized
    assert_bearer_challenge error: "invalid_request"
  end

  test "a session cookie still authenticates JSON" do
    sign_in_as :david

    get boards_path(format: :json)
    assert_response :success
  end

  private
    def bearer_token_env(token)
      { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
    end

    def assert_bearer_challenge(error: nil)
      challenge = response.headers["WWW-Authenticate"]

      assert_match(/\ABearer realm="Application"/, challenge)
      assert_match 'resource_metadata="http://www.example.com/.well-known/oauth-protected-resource"', challenge
      assert_match %(error="#{error}"), challenge if error
    end
end
