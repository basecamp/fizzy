require "test_helper"

class Boards::Columns::StreamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get board_columns_stream_path(boards(:writebook))
    assert_response :success
  end

  test "show as JSON" do
    get board_columns_stream_path(boards(:writebook)), as: :json
    assert_response :success

    assert_kind_of Array, @response.parsed_body
    assert response.headers["X-Total-Count"].present?, "Expected X-Total-Count header"
  end

  test "invalidates cache when a card is deleted" do
    card = create_full_page_of_cards(boards(:writebook)).fifth

    get board_columns_stream_path(boards(:writebook))
    etag = response.headers["ETag"]

    delete card_path(card)
    follow_redirect!

    get board_columns_stream_path(boards(:writebook)), headers: { "If-None-Match" => etag }
    assert_response :success
  end
end
