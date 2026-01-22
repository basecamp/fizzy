require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "high_priority_push? is true for card_assigned" do
    event = events(:logo_assignment_jz)

    assert event.high_priority_push?
  end

  test "high_priority_push? is false for comment_created" do
    event = events(:layout_commented)

    assert_not event.high_priority_push?
  end

  test "high_priority_push? is false for card_published" do
    event = events(:logo_published)

    assert_not event.high_priority_push?
  end

  test "high_priority_push? is false for card_closed" do
    event = events(:shipping_closed)

    assert_not event.high_priority_push?
  end
end
