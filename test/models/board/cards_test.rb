require "test_helper"

class Board::CardsTest < ActiveSupport::TestCase
  test "touch cards when the name changes" do
    board = boards(:writebook)

    assert_changes -> { board.cards.first.updated_at } do
      board.update!(name: "New Name")
    end

    assert_no_changes -> { board.cards.first.updated_at } do
      board.update!(updated_at: 1.hour.from_now)
    end
  end
end
