require "test_helper"

class Columns::LeftPositionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "move column left" do
    board = boards(:writebook)
    columns = board.columns.sorted.to_a

    column_a = columns[0]
    column_b = columns[1]
    original_position_a = column_a.position
    original_position_b = column_b.position

    post column_left_position_path(column_b), as: :turbo_stream
    assert_response :success

    assert_equal original_position_b, column_a.reload.position
    assert_equal original_position_a, column_b.reload.position
  end

  test "move left refreshes adjacent columns" do
    column = columns(:writebook_in_progress)

    post column_left_position_path(column), as: :turbo_stream

    column.reload.adjacent_columns.each do |adjacent_column|
      assert_turbo_stream action: :replace, target: dom_id(adjacent_column)
    end
  end

  test "users can only reorder columns in boards they have access to" do
    column = columns(:writebook_in_progress)

    post column_left_position_path(column), as: :turbo_stream
    assert_response :success

    boards(:writebook).update! all_access: false
    boards(:writebook).accesses.revoke_from users(:kevin)

    post column_left_position_path(column), as: :turbo_stream
    assert_response :not_found
  end
end
