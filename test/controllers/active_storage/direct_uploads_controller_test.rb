require "test_helper"

class ActiveStorage::DirectUploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @blob_params = {
      blob: {
        filename: "screenshot.png",
        byte_size: 12345,
        checksum: "GQ5SqLsM7ylnji0Wgd9wNC==",
        content_type: "image/png"
      }
    }
  end

  test "create" do
    sign_in_as :david

    post rails_direct_uploads_path,
      params: @blob_params,
      headers: bearer_token_header(identity_access_tokens(:davids_api_token).token),
      as: :json

    assert_response :success
    assert_includes response.parsed_body.keys, "direct_upload"
  end

  test "create with valid access token" do
    post rails_direct_uploads_path,
      params: @blob_params,
      headers: bearer_token_header(identity_access_tokens(:davids_api_token).token),
      as: :json

    assert_response :success
    assert_includes response.parsed_body.keys, "direct_upload"
  end

  test "create with read-only access token" do
    post rails_direct_uploads_path,
      params: @blob_params,
      headers: bearer_token_header(identity_access_tokens(:jasons_api_token).token),
      as: :json

    assert_response :unauthorized
  end

  test "create with invalid access token" do
    post rails_direct_uploads_path,
      params: @blob_params,
      headers: bearer_token_header("invalid_token"),
      as: :json

    assert_response :unauthorized
  end

  test "create unauthenticated" do
    post rails_direct_uploads_path,
      params: @blob_params,
      as: :json

    assert_response :redirect
  end

  test "create in another account is forbidden" do
    sign_in_as :david

    post rails_direct_uploads_path(script_name: "/#{ActiveRecord::FixtureSet.identify("initech")}"),
      params: @blob_params,
      as: :json

    assert_response :forbidden
  end

  test "create with valid access token in another account is forbidden" do
    post rails_direct_uploads_path(script_name: "/#{ActiveRecord::FixtureSet.identify("initech")}"),
      params: @blob_params,
      headers: bearer_token_header(identity_access_tokens(:davids_api_token).token),
      as: :json

    assert_response :forbidden
  end

  private
    def bearer_token_header(token)
      { "Authorization" => "Bearer #{token}" }
    end
end
