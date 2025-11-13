require "test_helper"

class Cards::Comments::ReactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :jz
    @comment = comments(:logo_agreement_jz)
    @card = @comment.card
  end

  test "create" do
    assert_difference -> { @comment.reactions.count }, 1 do
      post card_comment_reactions_path(@comment.card, @comment, format: :turbo_stream), params: { reaction: { content: "Great work!" } }
      assert_turbo_stream action: :replace, target: dom_id(@comment, :reacting)
    end
  end

  test "destroy" do
    reaction = reactions(:kevin)
    assert_difference -> { @comment.reactions.count }, -1 do
      delete card_comment_reaction_path(@comment.card, @comment, reaction, format: :turbo_stream)
      assert_turbo_stream action: :remove, target: dom_id(reaction)
    end
  end
end
