require "test_helper"

class Bubbles::CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    assert_difference "bubbles(:logo).messages.comments.count", +1 do
      post bubble_comments_url(bubbles(:logo), params: { comment: { body: "Agreed." } })
    end

    assert_response :success
  end

  test "update" do
    put bubble_comment_url(bubbles(:logo), comments(:logo_agreement_kevin)), params: { comment: { body: "I've changed my mind" } }

    assert_response :success
    assert_equal "I've changed my mind", comments(:logo_agreement_kevin).reload.body.content
  end

  test "update another user's comment" do
    assert_no_changes "comments(:logo_agreement_jz).body.content" do
      put bubble_comment_url(bubbles(:logo), comments(:logo_agreement_jz)), params: { comment: { body: "I've changed my mind" } }
    end

    assert_response :forbidden
  end
end
