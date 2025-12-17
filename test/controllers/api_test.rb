require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  setup do
    @davids_bearer_token = bearer_token_env(identity_access_tokens(:davids_api_token).token)
    @jasons_bearer_token = bearer_token_env(identity_access_tokens(:jasons_api_token).token)
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
