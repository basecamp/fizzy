require "test_helper"

class Public::CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
    @card = cards(:logo)
    @board.publish
  end

  test "show" do
    get public_board_card_path(@board.publication.key, @card)
    assert_response :success
  end

  test "not found if the board is not published" do
    @board.unpublish
    get public_board_card_path(@board.publication.key, @card)
    assert_response :not_found
  end

  test "not found if the card is drafted" do
    @card.update!(status: :drafted)
    get public_board_card_path(@board.publication.key, @card)
    assert_response :not_found
  end
end
