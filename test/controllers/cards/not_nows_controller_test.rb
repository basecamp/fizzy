require "test_helper"

class Cards::NotNowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)

    assert_changes -> { card.reload.postponed? }, from: false, to: true do
      post card_not_now_path(card), as: :turbo_stream
      assert_card_container_rerendered(card)
    end
  end

  test "create as JSON" do
    card = cards(:logo)

    assert_not card.postponed?

    post card_not_now_path(card), as: :json

    assert_response :no_content
    assert card.reload.postponed?
  end
end
