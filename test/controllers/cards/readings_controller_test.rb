require "test_helper"

class Bubbles::ReadingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      post bubble_reading_url(bubbles(:logo)), as: :turbo_stream
    end

    assert_response :success
  end
end
