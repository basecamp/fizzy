require "test_helper"

class Cards::GoldnessesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    assert_changes -> { cards(:text).reload.golden? }, from: false, to: true do
      post card_goldness_path(cards(:text)), as: :turbo_stream
      assert_card_container_rerendered(cards(:text))
    end
  end

  test "destroy" do
    assert_changes -> { cards(:logo).reload.golden? }, from: true, to: false do
      delete card_goldness_path(cards(:logo)), as: :turbo_stream
      assert_card_container_rerendered(cards(:logo))
    end
  end

  test "create as JSON" do
    card = cards(:text)

    assert_not card.golden?

    post card_goldness_path(card), as: :json

    assert_response :no_content
    assert card.reload.golden?
  end

  test "destroy as JSON" do
    card = cards(:logo)

    assert card.golden?

    delete card_goldness_path(card), as: :json

    assert_response :no_content
    assert_not card.reload.golden?
  end
end
