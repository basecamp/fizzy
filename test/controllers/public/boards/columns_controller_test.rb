require "test_helper"

class Public::Boards::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    boards(:writebook).publish
  end

  test "show" do
    column = columns(:writebook_in_progress)
    get public_board_column_path(boards(:writebook).publication.key, column)
    assert_response :success
  end
end
