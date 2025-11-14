require "test_helper"

class Cards::CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    assert_difference -> { cards(:logo).comments.count }, +1 do
      post card_comments_path(cards(:logo)), params: { comment: { body: "Agreed." } }, as: :turbo_stream
    end

    assert_response :success
  end

  test "update" do
    put card_comment_path(cards(:logo), comments(:logo_agreement_kevin)), params: { comment: { body: "I've changed my mind" } }, as: :turbo_stream

    assert_response :success
    assert_action_text "I've changed my mind", comments(:logo_agreement_kevin).reload.body
  end

  test "update another user's comment" do
    assert_no_changes -> { comments(:logo_agreement_jz).reload.body.to_s } do
      put card_comment_path(cards(:logo), comments(:logo_agreement_jz)), params: { comment: { body: "I've changed my mind" } }, as: :turbo_stream
    end

    assert_response :forbidden
  end
end
