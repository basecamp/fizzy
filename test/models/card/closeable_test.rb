require "test_helper"

class Card::CloseableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "closed scope" do
    assert_equal [ cards(:shipping) ], Card.closed
    assert_not_includes Card.open, cards(:shipping)
  end

  test "close cards" do
    assert_not cards(:logo).closed?

    assert_difference -> { cards(:logo).events.count }, +1 do
      cards(:logo).close(user: users(:kevin))
    end

    assert cards(:logo).closed?
    assert cards(:logo).events.last.action.card_closed?
    assert_equal users(:kevin), cards(:logo).closed_by
  end

  test "reopen cards" do
    assert cards(:shipping).closed?

    assert_difference -> { cards(:shipping).events.count }, +1 do
      cards(:shipping).reopen
    end
    assert cards(:shipping).reload.open?
    assert cards(:shipping).events.last.action.card_reopened?
  end
end
