require "test_helper"

class Board::EntropicTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "a new board saves its auto-postpone period along with itself" do
    board = Board.new name: "Fresh", auto_postpone_period_in_days: 7

    assert board.entropy.new_record?

    board.save!

    assert_equal 7.days, board.entropy.reload.auto_postpone_period
    assert_equal board.account, board.entropy.account
    assert_equal 30.days, entropies("37s_account").reload.auto_postpone_period
  end

  test "an invalid auto-postpone period fails the board's save" do
    assert_no_difference -> { Board.count } do
      assert_raises ActiveRecord::RecordInvalid do
        Board.create! name: "Fresh", auto_postpone_period_in_days: 1
      end
    end
  end

  test "changing the auto-postpone period saves with the board" do
    board = boards(:writebook)

    board.auto_postpone_period_in_days = 7
    assert_equal 90.days, entropies(:writebook_board).reload.auto_postpone_period

    board.save!
    assert_equal 7.days, entropies(:writebook_board).reload.auto_postpone_period
  end

  test "an invalid auto-postpone period leaves the board and its entropy unchanged" do
    board = boards(:writebook)

    assert_raises ActiveRecord::RecordInvalid do
      board.update! name: "Renamed", auto_postpone_period_in_days: 1
    end

    assert_equal "Writebook", board.reload.name
    assert_equal 90.days, entropies(:writebook_board).reload.auto_postpone_period
  end
end
