require "test_helper"

class Board::WorkPlanTest < ActiveSupport::TestCase
  test "planning time limit defaults to 30 seconds" do
    board = with_current_user(:kevin) do
      Board.create!(name: "Planner defaults", creator: users(:kevin), all_access: true)
    end

    assert_equal 30, board.work_planning_time_limit_in_seconds
  end

  test "planning time limit only accepts configured presets" do
    board = boards(:writebook)

    assert_raises ActiveRecord::RecordInvalid do
      board.update!(work_planning_time_limit_in_seconds: 15)
    end
  end
end
