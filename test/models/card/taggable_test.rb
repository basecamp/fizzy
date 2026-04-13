require "test_helper"

class Card::TaggableTest < ActiveSupport::TestCase
  setup do
    @card = cards(:logo)
  end

  test "toggle tag" do
    assert_difference -> { @card.tags.count }, 1 do
      @card.toggle_tag_with "ruby"
    end

    assert_equal "ruby", @card.tags.last.title

    assert_difference -> { @card.tags.count }, -1 do
      @card.toggle_tag_with "ruby"
    end
  end

  test "scope tags by account" do
    assert_difference -> { Tag.count }, 2 do
      cards(:logo).toggle_tag_with "ruby"
      cards(:paycheck).toggle_tag_with "ruby"
    end

    assert_not_equal cards(:logo).tags.last, cards(:paycheck).tags.last
  end

  test "updating just tag_ids touches the card and board" do
    board = @card.board
    card_updated_at = @card.updated_at
    board_updated_at = board.updated_at

    travel 1.minute do
      @card.update!(tag_ids: [ tags(:web).id, tags(:mobile).id ])
    end

    assert @card.reload.updated_at > card_updated_at
    assert board.reload.updated_at > board_updated_at
  end
end
