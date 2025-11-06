require "test_helper"

class Public::Boards::Columns::ClosedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    boards(:writebook).publish
  end

  test "show" do
    get public_board_columns_closed_path(boards(:writebook).publication.key)
    assert_response :success
  end
end
