require "test_helper"

class Bubbles::PopsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    bubble = bubbles(:logo)

    assert_changes -> { bubble.reload.popped? }, from: false, to: true do
      post bubble_pop_url(bubble, reason: "Scope too big")
    end

    assert_equal "Scope too big", bubble.pop.reason

    assert_redirected_to bucket_bubble_url(bubble.bucket, bubble)
  end

  test "destroy" do
    bubble = bubbles(:shipping)

    assert_changes -> { bubble.reload.popped? }, from: true, to: false do
      delete bubble_pop_url(bubble)
    end

    assert_redirected_to bucket_bubble_url(bubble.bucket, bubble)
  end
end
