require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    assert_difference "cards(:logo).messages.comments.count", +1 do
      post collection_card_comments_url(collections(:writebook), cards(:logo), params: { comment: { body: "Agreed." } })
    end

    assert_response :success
  end

  test "update" do
    put collection_card_comment_url(collections(:writebook), cards(:logo), comments(:logo_agreement_kevin)), params: { comment: { body: "I've changed my mind" } }

    assert_response :success
    assert_equal "I've changed my mind", comments(:logo_agreement_kevin).reload.body.content
  end

  test "update another user's comment" do
    assert_no_changes "comments(:logo_agreement_jz).body.content" do
      put collection_card_comment_url(collections(:writebook), cards(:logo), comments(:logo_agreement_jz)), params: { comment: { body: "I've changed my mind" } }
    end

    assert_response :forbidden
  end
end
