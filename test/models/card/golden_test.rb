require "test_helper"

class Card::GoldenTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @golden, @non_golden = cards(:logo), cards(:text)
  end

  test "check whether a card is golden" do
    assert @golden.golden?
    assert_not @non_golden.golden?
  end

  test "promote and demote from golden" do
    assert_changes -> { @non_golden.reload.golden? }, to: true do
      @non_golden.gild
    end

    assert_changes -> { @golden.reload.golden? }, to: false do
      @golden.ungild
    end
  end

  test "scopes" do
    assert_includes Card.golden, @golden
    assert_not_includes Card.golden, @non_golden
  end

  test "with_golden_first orders golden first" do
    ordered = Card.where(id: [ @golden.id, @non_golden.id ]).with_golden_first
    assert_equal [ @golden, @non_golden ], ordered.to_a

    # Preserves base ordering as subordering
    @non_golden.gild
    base_ordered = Card.where(id: [ @golden.id, @non_golden.id ]).order(id: :desc).to_a
    with_golden = Card.where(id: [ @golden.id, @non_golden.id ]).order(id: :desc).with_golden_first.to_a
    assert_equal base_ordered, with_golden
  end

  test "gilding a card touches both the card and the board" do
    board = @non_golden.board

    card_updated_at = @non_golden.updated_at
    board_updated_at = board.updated_at

    travel 1.minute do
      @non_golden.gild
    end

    assert @non_golden.reload.updated_at > card_updated_at
    assert board.reload.updated_at > board_updated_at
  end
end
