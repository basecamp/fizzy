require "test_helper"

class Comments::ReactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :jz
    @comment = comments(:logo_agreement_jz)
  end

  test "create" do
    assert_turbo_stream_broadcasts [ @comment, :comments ], count: 1 do
      assert_difference -> { @comment.reactions.count }, 1 do
        post collection_card_comment_reactions_url(@comment.card.collection, @comment.card, @comment, format: :turbo_stream), params: { reaction: { content: "Great work!" } }
        assert_redirected_to collection_card_comment_reactions_url(@comment.card.collection, @comment.card, @comment)
      end
    end
  end

  test "destroy" do
    assert_turbo_stream_broadcasts [ @comment, :comments ], count: 1 do
      assert_difference -> { @comment.reactions.count }, -1 do
        delete collection_card_comment_reaction_url(@comment.card.collection, @comment.card, @comment, reactions(:kevin), format: :turbo_stream)
        assert_response :success
      end
    end
  end
end
