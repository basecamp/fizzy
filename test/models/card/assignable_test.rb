require "test_helper"

class Bubble::AssignableTest < ActiveSupport::TestCase
  test "assigning a user makes them watch the bubble" do
    assert_not bubbles(:layout).assigned_to?(users(:kevin))
    bubbles(:layout).unwatch_by users(:kevin)

    with_current_user(:jz) do
      bubbles(:layout).toggle_assignment(users(:kevin))
    end

    assert bubbles(:layout).assigned_to?(users(:kevin))
    assert bubbles(:layout).watched_by?(users(:kevin))
  end
end
