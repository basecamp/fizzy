require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  test "authenticate with valid access token" do
    get boards_path(format: :json), env: bearer_token_env(identity_access_tokens(:jasons_api_token).token)
    assert_response :success
  end

  test "fail to authenticate with invalid access token" do
    get boards_path(format: :json), env: bearer_token_env("nonsense")
    assert_response :unauthorized
  end

  private
    def bearer_token_env(token)
      { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
    end
end
