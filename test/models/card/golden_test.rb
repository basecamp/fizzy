require "test_helper"

class Card::GoldenTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "check whether a card is golden" do
    assert cards(:logo).golden?
    assert_not cards(:text).golden?
  end

  test "promote and demote from golden" do
    assert_changes -> { cards(:text).reload.golden? }, to: true do
      cards(:text).gild
    end

    assert_changes -> { cards(:logo).reload.golden? }, to: false do
      cards(:logo).ungild
    end
  end

  test "scopes" do
    assert_includes Card.golden, cards(:logo)
    assert_not_includes Card.golden, cards(:text)
  end

  test "with_golden_first scope orders golden cards first" do
    golden_card = cards(:logo)
    non_golden_card = cards(:text)

    # Ensure we have at least one golden and one non-golden card
    assert golden_card.golden?
    assert_not non_golden_card.golden?

    # Get all cards from the same account/board with golden first
    cards_ordered = Card.where(id: [ golden_card.id, non_golden_card.id ]).with_golden_first

    # The golden card should come before the non-golden card
    assert_equal golden_card.id, cards_ordered.first.id
    assert_equal non_golden_card.id, cards_ordered.last.id
  end

  test "gilding a card touches both the card and the board" do
    card = cards(:text)
    board = card.board

    card_updated_at = card.updated_at
    board_updated_at = board.updated_at

    travel 1.minute do
      card.gild
    end

    assert card.reload.updated_at > card_updated_at
    assert board.reload.updated_at > board_updated_at
  end
end
