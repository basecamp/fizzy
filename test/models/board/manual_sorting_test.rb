require "test_helper"

class Board::ManualSortingTest < ActiveSupport::TestCase
  test "manual sorting is disabled by default" do
    board = boards(:writebook)
    assert_equal false, board.manual_sorting_enabled?
  end
end

