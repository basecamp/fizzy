require "test_helper"

class UploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    assert_changes -> { ActiveStorage::Attachment.count }, 1 do
      post uploads_url(format: "json"), params: { file: fixture_file_upload("moon.jpg", "image/jpeg") }, as: :xhr
    end

    assert_response :success
    assert_equal ActiveStorage::Attachment.last.slug_url(host: "#{ApplicationRecord.current_tenant}.example.com", port: nil), response.parsed_body["fileUrl"]
    assert_equal "image/jpeg", response.parsed_body["mimetype"]
    assert_equal "moon.jpg", response.parsed_body["fileName"]
  end

  test "show" do
    accounts("37s").uploads.attach fixture_file_upload("moon.jpg", "image/jpeg")
    get upload_url(slug: accounts("37s").uploads.last.slug)
    assert_response :redirect
    assert_match /\/rails\/active_storage\/.*\/moon\.jpg/, @response.redirect_url
  end
end
