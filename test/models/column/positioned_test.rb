require "test_helper"

class Column::PositionedTest < ActiveSupport::TestCase
  test "auto position new columns" do
    board = boards(:writebook)
    max_position = board.columns.maximum(:position)

    new_column = board.columns.create!(name: "New Column", color: "#000000")

    assert_equal max_position + 1, new_column.position
  end

  test "move column to the left" do
    board = boards(:writebook)
    columns = board.columns.sorted.to_a

    column_a = columns[0]
    column_b = columns[1]
    original_position_a = column_a.position
    original_position_b = column_b.position

    column_b.move_left

    assert_equal original_position_b, column_a.reload.position
    assert_equal original_position_a, column_b.reload.position
  end

  test "move left when already at leftmost position" do
    board = boards(:writebook)
    leftmost_column = board.columns.sorted.first
    original_position = leftmost_column.position

    leftmost_column.move_left

    assert_equal original_position, leftmost_column.reload.position
  end

  test "move column to the right" do
    board = boards(:writebook)
    columns = board.columns.sorted.to_a

    column_a = columns[0]
    column_b = columns[1]
    original_position_a = column_a.position
    original_position_b = column_b.position

    column_a.move_right

    assert_equal original_position_b, column_a.reload.position
    assert_equal original_position_a, column_b.reload.position
  end

  test "move right when already at rightmost position" do
    board = boards(:writebook)
    rightmost_column = board.columns.sorted.last
    original_position = rightmost_column.position

    rightmost_column.move_right

    assert_equal original_position, rightmost_column.reload.position
  end
end
