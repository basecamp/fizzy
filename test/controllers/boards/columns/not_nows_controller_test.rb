require "test_helper"

class Boards::Columns::NotNowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get board_columns_not_now_path(boards(:writebook))
    assert_response :success
  end

  test "show as JSON" do
    get board_columns_not_now_path(boards(:writebook)), as: :json
    assert_response :success

    assert_kind_of Array, @response.parsed_body
  end

  test "invalidates cache when a card moves to another board" do
    card = create_full_page_of_cards(boards(:writebook), &:postpone).fifth

    get board_columns_not_now_path(boards(:writebook))
    etag = response.headers["ETag"]

    put card_board_path(card), params: { board_id: boards(:private).id }

    get board_columns_not_now_path(boards(:writebook)), headers: { "If-None-Match" => etag }
    assert_response :success
  end
end
