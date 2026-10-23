require "test_helper"

class Card::BubblesUpTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @bubbling, @non_bubbling = cards(:postponed_idea), cards(:text)
    @bubble_up_time = 1.week.from_now
  end

  test "check whether a card is bubbling" do
    assert @bubbling.bubble_up?
    assert @bubbling.bubbling?
    assert_not @bubbling.bubbled?

    assert_not @non_bubbling.bubble_up?
    assert_not @non_bubbling.bubbling?
    assert_not @non_bubbling.bubbled?
  end

  test "check whether a card has bubbled up" do
    travel_to @bubbling.bubble_up.resurface_at + 1.minute do
      assert @bubbling.bubble_up?
      assert @bubbling.bubbled?
      assert_not @bubbling.bubbling?
    end
  end

  test "bubble up and pop a card" do
    assert_changes -> { @non_bubbling.reload.bubble_up? }, to: true do
      @non_bubbling.bubble_up_at(@bubble_up_time)
    end

    assert_changes -> { @bubbling.reload.bubble_up? }, to: false do
      @bubbling.pop
    end
  end

  test "marking a card to bubble up postpones the card" do
    assert_not @non_bubbling.postponed?
    @non_bubbling.bubble_up_at(@bubble_up_time)
    assert @non_bubbling.reload.postponed?
  end

  test "change when a bubble up resurfaces" do
    @bubbling.bubble_up_at(@bubble_up_time)
    assert_in_delta @bubble_up_time, @bubbling.reload.bubble_up.resurface_at, 1.second
  end

  test "bubbling up a card touches both the card and the board" do
    board = @non_bubbling.board

    card_updated_at = @non_bubbling.updated_at
    board_updated_at = board.updated_at

    travel 1.minute do
      @non_bubbling.bubble_up_at(@bubble_up_time)
    end

    assert @non_bubbling.reload.updated_at > card_updated_at
    assert board.reload.updated_at > board_updated_at
  end
end
