require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
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
  end

  test "changing data requires a write-endowed access token" do
    post boards_path(format: :json), params: { board: { name: "My new board" } }, env: @jasons_bearer_token
    assert_response :unauthorized

    post boards_path(format: :json), params: { board: { name: "My new board" } }, env: @davids_bearer_token
    assert_response :success
  end

  private
    def bearer_token_env(token)
      { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
    end
end
