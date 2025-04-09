require "test_helper"

class Card::AssignableTest < ActiveSupport::TestCase
  test "assigning a user makes them watch the card" do
    assert_not cards(:layout).assigned_to?(users(:kevin))
    cards(:layout).unwatch_by users(:kevin)

    with_current_user(:jz) do
      cards(:layout).toggle_assignment(users(:kevin))
    end

    assert cards(:layout).assigned_to?(users(:kevin))
    assert cards(:layout).watched_by?(users(:kevin))
  end
end
