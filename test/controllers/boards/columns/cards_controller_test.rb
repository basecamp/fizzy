require "test_helper"

class Boards::Columns::CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index as JSON" do
    column = columns(:writebook_in_progress)

    get board_column_cards_path(column.board, column), as: :json

    assert_response :success
    assert_kind_of Array, @response.parsed_body
    assert_equal [ cards(:text).number ], @response.parsed_body.pluck("number")
    assert_equal "1", response.headers["X-Total-Count"]
  end

  test "cannot access cards on board without access as JSON" do
    board = boards(:private)
    column = board.columns.create!(name: "Secret")

    logout_and_sign_in_as :jason

    get board_column_cards_path(board, column), as: :json

    assert_response :not_found
  end
end
