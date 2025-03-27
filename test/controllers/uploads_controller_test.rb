require "test_helper"

class UploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    bubble = bubbles(:logo)

    assert_changes -> { ActiveStorage::Attachment.count }, 1 do
      assert_changes -> { bubble.uploads.count }, 1 do
        post bucket_bubble_uploads_url(bubble.bucket, bubble, format: "json"), params: { file: fixture_file_upload("moon.jpg", "image/jpeg") }, as: :xhr

        assert_response :success
      end
    end

    assert_equal ActiveStorage::Attachment.last.slug_url(host: "#{ApplicationRecord.current_tenant}.example.com", port: nil), response.parsed_body["fileUrl"]
    assert_equal "image/jpeg", response.parsed_body["mimetype"]
    assert_equal "moon.jpg", response.parsed_body["fileName"]
  end
end
