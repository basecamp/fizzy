require "test_helper"

class Cards::ClosuresControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)

    assert_changes -> { card.reload.closed? }, from: false, to: true do
      post card_closure_url(card, reason: "Scope too big")
    end

    assert_equal "Scope too big", card.closure.reason

    assert_redirected_to collection_card_url(card.collection, card)
  end

  test "destroy" do
    card = cards(:shipping)

    assert_changes -> { card.reload.closed? }, from: true, to: false do
      delete card_closure_url(card)
    end

    assert_redirected_to collection_card_url(card.collection, card)
  end
end
