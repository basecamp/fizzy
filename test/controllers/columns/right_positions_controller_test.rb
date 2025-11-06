require "test_helper"

class Columns::RightPositionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "move column right" do
    board = boards(:writebook)
    columns = board.columns.sorted.to_a

    column_a = columns[0]
    column_b = columns[1]
    original_position_a = column_a.position
    original_position_b = column_b.position

    post column_right_position_path(column_a), as: :turbo_stream
    assert_response :success

    assert_equal original_position_b, column_a.reload.position
    assert_equal original_position_a, column_b.reload.position
  end
end
