require "test_helper"

class Bubbles::EngagementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    bubble = bubbles(:text)

    assert_changes -> { bubble.reload.doing? }, from: false, to: true do
      post bubble_engagement_url(bubble)
    end

    assert_redirected_to bucket_bubble_url(bubble.bucket, bubble)
  end

  test "destroy" do
    bubble = bubbles(:logo)

    assert_changes -> { bubble.reload.doing? }, from: true, to: false do
      delete bubble_engagement_url(bubble)
    end

    assert_redirected_to bucket_bubble_url(bubble.bucket, bubble)
  end
end
