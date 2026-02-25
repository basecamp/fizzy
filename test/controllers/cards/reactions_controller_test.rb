require "test_helper"

class Cards::ReactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
    @card = cards(:logo)
  end

  test "index" do
    get card_reactions_path(@card)
    assert_response :success
  end

  test "new" do
    get new_card_reaction_path(@card)
    assert_response :success
  end

  test "create" do
    assert_difference -> { @card.reactions.count }, 1 do
      post card_reactions_path(@card, format: :turbo_stream), params: { reaction: { content: "Great work!" } }
      assert_turbo_stream action: :replace, target: dom_id(@card, :reacting)
    end
  end

  test "destroy" do
    reaction = reactions(:logo_card_david)
    assert_difference -> { @card.reactions.count }, -1 do
      delete card_reaction_path(@card, reaction, format: :turbo_stream)
      assert_turbo_stream action: :remove, target: dom_id(reaction)
    end
  end

  test "non-owner cannot destroy reaction" do
    reaction = reactions(:logo_card_kevin)

    assert_no_difference -> { @card.reactions.count } do
      delete card_reaction_path(@card, reaction, format: :turbo_stream)
      assert_response :forbidden
    end
  end

  test "index as JSON" do
    get card_reactions_path(@card), as: :json

    assert_response :success
    assert_equal @card.reactions.count, @response.parsed_body.count
  end

  test "create as JSON" do
    assert_difference -> { @card.reactions.count }, 1 do
      post card_reactions_path(@card), params: { reaction: { content: "👍" } }, as: :json
    end

    assert_response :created
  end

  test "destroy as JSON" do
    reaction = reactions(:logo_card_david)

    assert_difference -> { @card.reactions.count }, -1 do
      delete card_reaction_path(@card, reaction), as: :json
    end

    assert_response :no_content
  end
end
