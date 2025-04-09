require "test_helper"

class Bubbles::PublishesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    bubble = bubbles(:logo)
    bubble.drafted!

    assert_changes -> { bubble.reload.published? }, from: false, to: true do
      post bubble_publish_path(bubble)
    end

    assert_redirected_to bubble
  end
end
