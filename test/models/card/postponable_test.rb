require "test_helper"

class Card::PostponableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "check the postponed status of a card" do
    card = cards(:logo)

    assert_not card.postponed?
    assert card.active?

    card.postpone
    assert card.postponed?
    assert_not card.active?
  end

  test "postpone and resume a card" do
    card = cards(:text)

    assert_changes -> { card.reload.postponed? }, to: true do
      assert_difference -> { card.events.count }, +1 do
        card.postpone
      end
    end

    assert_equal users(:david), card.not_now.user
    assert card.events.last.action.card_postponed?

    assert_changes -> { card.reload.postponed? }, to: false do
      card.resume
    end
  end

  test "auto_postpone a card" do
    card = cards(:text)

    assert_changes -> { card.reload.postponed? }, to: true do
      assert_difference -> { card.events.count }, +1 do
        card.auto_postpone
      end
    end

    assert card.events.last.action.card_auto_postponed?
  end

  test "postponing pops bubble up if present" do
    card = cards(:text)
    card.bubble_up_at 1.hour.ago

    assert card.bubble_up?
    card.postpone

    assert_not card.reload.bubble_up?
    assert card.events.last.action.card_postponed?
  end

  test "scopes" do
    logo = cards(:logo)
    text = cards(:text)

    logo.postpone

    assert_includes Card.postponed, logo
    assert_not_includes Card.postponed, text

    assert_includes Card.active, text
    assert_not_includes Card.active, logo
  end
end
