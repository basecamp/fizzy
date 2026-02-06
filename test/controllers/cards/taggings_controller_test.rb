require "test_helper"

class Cards::TaggingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_card_tagging_path(cards(:logo))
    assert_response :success
  end

  test "toggle tag on" do
    assert_changes "cards(:logo).tagged_with?(tags(:mobile))", from: false, to: true do
      post card_taggings_path(cards(:logo)), params: { tag_title: tags(:mobile).title }, as: :turbo_stream
      assert_turbo_stream action: :replace, target: dom_id(cards(:logo), :tags)
    end
  end

  test "toggle tag off" do
    assert_changes "cards(:logo).tagged_with?(tags(:web))", from: true, to: false do
      post card_taggings_path(cards(:logo)), params: { tag_title: tags(:web).title }, as: :turbo_stream
      assert_turbo_stream action: :replace, target: dom_id(cards(:logo), :tags)
    end
  end

  test "toggle tag on as JSON" do
    card = cards(:logo)

    assert_not card.tagged_with?(tags(:mobile))

    post card_taggings_path(card), params: { tag_title: tags(:mobile).title }, as: :json

    assert_response :no_content
    assert card.reload.tagged_with?(tags(:mobile))
  end

  test "toggle tag off as JSON" do
    card = cards(:logo)

    assert card.tagged_with?(tags(:web))

    post card_taggings_path(card), params: { tag_title: tags(:web).title }, as: :json

    assert_response :no_content
    assert_not card.reload.tagged_with?(tags(:web))
  end
end
