require "test_helper"

class Cards::DraftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    card = boards(:writebook).cards.create!(creator: users(:kevin), status: :drafted)

    get card_draft_path(card)
    assert_response :success
  end

  test "show redirects to card when published" do
    card = cards(:logo)

    get card_draft_path(card)
    assert_redirected_to card
  end
end
