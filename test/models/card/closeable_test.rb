require "test_helper"

class Bubble::PoppableTest < ActiveSupport::TestCase
  test "popped scope" do
    assert_equal [ bubbles(:shipping) ], Bubble.popped
    assert_not_includes Bubble.active, bubbles(:shipping)
  end

  test "popping" do
    assert_not bubbles(:logo).popped?

    bubbles(:logo).pop!(user: users(:kevin))

    assert bubbles(:logo).popped?
    assert_equal users(:kevin), bubbles(:logo).popped_by
  end

  test "auto_pop_all_due" do
    bubbles(:logo, :shipping).each(&:reconsider)

    bubbles(:logo).update!(last_active_at: 1.day.ago - Bubble::Poppable::AUTO_POP_AFTER)
    bubbles(:shipping).update!(last_active_at: 1.day.from_now - Bubble::Poppable::AUTO_POP_AFTER)

    assert_difference -> { Bubble.popped.count }, +1 do
      Bubble.auto_pop_all_due
    end

    assert bubbles(:logo).reload.popped?
    assert_not bubbles(:shipping).reload.popped?
  end
end
