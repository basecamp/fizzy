require "test_helper"

class Cards::BubbleUpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:initech)
    sign_in_as :mike

    integration_session.default_url_options[:script_name] = "/#{@account.external_account_id}"
  end

  test "create" do
    assert_changes -> { cards(:radio).reload.bubble_up? }, from: false, to: true do
      post card_bubble_up_path(cards(:radio)), params: { slot: "tomorrow" }, as: :turbo_stream
      assert_card_container_rerendered(cards(:radio))
    end
  end

  test "destroy" do
    assert_changes -> { cards(:postponed_idea).reload.bubble_up? }, from: true, to: false do
      delete card_bubble_up_path(cards(:postponed_idea)), as: :turbo_stream
      assert_card_container_rerendered(cards(:postponed_idea))
    end
  end

  test "create as JSON" do
    card = cards(:radio)

    assert_not card.bubble_up?

    post card_bubble_up_path(card), as: :json

    assert_response :no_content
    assert card.reload.bubble_up?
  end

  test "destroy as JSON" do
    card = cards(:postponed_idea)

    assert card.bubble_up?

    delete card_bubble_up_path(card), as: :json

    assert_response :no_content
    assert_not card.reload.bubble_up?
  end
end
