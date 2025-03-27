require "test_helper"

class AttachmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    bubble = bubbles(:logo)
    bubble.uploads.attach fixture_file_upload("moon.jpg", "image/jpeg")

    get attachment_url(slug: bubble.uploads.last.slug)

    assert_response :redirect
    assert_match %r{/rails/active_storage/.*/moon\.jpg}, @response.redirect_url
  end
end
