require "test_helper"

class Cards::BoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update changes card board" do
    card = cards(:logo)
    new_board = boards(:private)

    assert_not_equal new_board, card.board

    assert_changes -> { card.reload.board }, from: card.board, to: new_board do
      put card_board_path(card), params: { board_id: new_board.id }
    end

    assert_redirected_to card
  end

  test "update as JSON" do
    card = cards(:logo)
    new_board = boards(:private)

    assert_not_equal new_board, card.board

    put card_board_path(card), params: { board_id: new_board.id }, as: :json

    assert_response :success
    assert_equal new_board, card.reload.board

    json = @response.parsed_body
    assert_equal card.id, json["id"]
    assert_equal card.number, json["number"]
    assert_equal card.title, json["title"]
    assert_equal new_board.id, json["board"]["id"]
  end
end
