require "test_helper"

class Api::DirectUploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:"37s")
    @token = identity_access_tokens(:davids_api_token)
  end

  test "create blob with bearer token authentication" do
    post "/#{@account.external_account_id}/api/direct_uploads.json",
      params: {
        blob: {
          filename: "test.jpg",
          byte_size: 1024,
          checksum: Base64.strict_encode64(Digest::MD5.digest("test")),
          content_type: "image/jpeg"
        }
      },
      headers: { "Authorization" => "Bearer #{@token.token}" }

    assert_response :success
    json = response.parsed_body

    assert json["attachable_sgid"].present?, "Response should include attachable_sgid"
    assert json["signed_id"].present?, "Response should include signed_id"
    assert json["direct_upload"]["url"].present?, "Response should include direct upload URL"
    assert json["direct_upload"]["headers"].present?, "Response should include direct upload headers"
  end

  test "create blob without authentication redirects to login" do
    post "/#{@account.external_account_id}/api/direct_uploads.json",
      params: {
        blob: {
          filename: "test.jpg",
          byte_size: 1024,
          checksum: Base64.strict_encode64(Digest::MD5.digest("test")),
          content_type: "image/jpeg"
        }
      }

    assert_response :redirect
  end
end
