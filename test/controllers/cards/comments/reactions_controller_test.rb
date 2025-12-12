require "test_helper"

class Cards::Comments::ReactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
    @comment = comments(:logo_agreement_jz)
    @card = @comment.card
  end

  test "index" do
    get card_comment_reactions_path(@card, @comment)
    assert_response :success
  end

  test "create" do
    assert_difference -> { @comment.reactions.count }, 1 do
      post card_comment_reactions_path(@comment.card, @comment, format: :turbo_stream), params: { reaction: { content: "Great work!" } }
      assert_turbo_stream action: :replace, target: dom_id(@comment, :reacting)
    end
  end

  test "destroy" do
    reaction = reactions(:david)
    assert_difference -> { @comment.reactions.count }, -1 do
      delete card_comment_reaction_path(@comment.card, @comment, reaction, format: :turbo_stream)
      assert_turbo_stream action: :remove, target: dom_id(reaction)
    end
  end

  test "non-owner cannot destroy reaction" do
    reaction = reactions(:kevin)

    assert_no_difference -> { @comment.reactions.count } do
      delete card_comment_reaction_path(@comment.card, @comment, reaction, format: :turbo_stream)
      assert_response :forbidden
    end
  end

  test "index as JSON" do
    get card_comment_reactions_path(@card, @comment), as: :json

    assert_response :success
    assert_equal @comment.reactions.count, @response.parsed_body.count
  end

  test "create as JSON" do
    assert_difference -> { @comment.reactions.count }, 1 do
      post card_comment_reactions_path(@card, @comment), params: { reaction: { content: "👍" } }, as: :json
    end

    assert_response :created
  end

  test "destroy as JSON" do
    reaction = reactions(:david)

    assert_difference -> { @comment.reactions.count }, -1 do
      delete card_comment_reaction_path(@card, @comment, reaction), as: :json
    end

    assert_response :no_content
  end
end
