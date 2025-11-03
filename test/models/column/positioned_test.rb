require "test_helper"

class Column::PositionedTest < ActiveSupport::TestCase
  test "auto position new columns" do
    collection = collections(:writebook)
    max_position = collection.columns.maximum(:position)

    new_column = collection.columns.create!(name: "New Column", color: "#000000")

    assert_equal max_position + 1, new_column.position
  end

  test "move column to the left" do
    collection = collections(:writebook)
    columns = collection.columns.sorted.to_a

    column_a = columns[0]
    column_b = columns[1]
    original_position_a = column_a.position
    original_position_b = column_b.position

    column_b.move_left

    assert_equal original_position_b, column_a.reload.position
    assert_equal original_position_a, column_b.reload.position
  end

  test "move left when already at leftmost position" do
    collection = collections(:writebook)
    leftmost_column = collection.columns.sorted.first
    original_position = leftmost_column.position

    leftmost_column.move_left

    assert_equal original_position, leftmost_column.reload.position
  end

  test "move column to the right" do
    collection = collections(:writebook)
    columns = collection.columns.sorted.to_a

    column_a = columns[0]
    column_b = columns[1]
    original_position_a = column_a.position
    original_position_b = column_b.position

    column_a.move_right

    assert_equal original_position_b, column_a.reload.position
    assert_equal original_position_a, column_b.reload.position
  end

  test "move right when already at rightmost position" do
    collection = collections(:writebook)
    rightmost_column = collection.columns.sorted.last
    original_position = rightmost_column.position

    rightmost_column.move_right

    assert_equal original_position, rightmost_column.reload.position
  end
end
