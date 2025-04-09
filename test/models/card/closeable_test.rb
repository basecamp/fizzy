require "test_helper"

class Card::CloseableTest < ActiveSupport::TestCase
  test "closed scope" do
    assert_equal [ cards(:shipping) ], Card.closed
    assert_not_includes Card.active, cards(:shipping)
  end

  test "popping" do
    assert_not cards(:logo).closed?

    cards(:logo).closure!(user: users(:kevin))

    assert cards(:logo).closed?
    assert_equal users(:kevin), cards(:logo).closed_by
  end

  test "auto_closure_all_due" do
    cards(:logo, :shipping).each(&:reconsider)

    cards(:logo).update!(last_active_at: 1.day.ago - Card::Closeable::AUTO_CLOSURE_AFTER)
    cards(:shipping).update!(last_active_at: 1.day.from_now - Card::Closeable::AUTO_CLOSURE_AFTER)

    assert_difference -> { Card.closed.count }, +1 do
      Card.auto_closure_all_due
    end

    assert cards(:logo).reload.closed?
    assert_not cards(:shipping).reload.closed?
  end
end
