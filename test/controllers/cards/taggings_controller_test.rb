require "test_helper"

class Cards::TaggingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_card_tagging_url(cards(:logo))
    assert_response :success
  end

  test "toggle tag on" do
    assert_changes "cards(:logo).tagged_with?(tags(:mobile))", from: false, to: true do
      post card_taggings_url(cards(:logo)), params: { tag_title: tags(:mobile).title }, as: :turbo_stream
    end
    assert_response :success
  end

  test "toggle tag off" do
    assert_changes "cards(:logo).tagged_with?(tags(:web))", from: true, to: false do
      post card_taggings_url(cards(:logo)), params: { tag_title: tags(:web).title }, as: :turbo_stream
    end
    assert_response :success
  end
end
