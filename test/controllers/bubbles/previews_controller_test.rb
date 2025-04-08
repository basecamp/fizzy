require "test_helper"

class Bubbles::PreviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get bubbles_previews_url(format: :turbo_stream)

    assert_response :success
  end
end
