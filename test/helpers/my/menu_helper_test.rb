require "test_helper"

class My::MenuHelperTest < ActionView::TestCase
  setup do
    @board = boards(:writebook)
  end

  test "board_column_counts_tag shows awaiting triage count first" do
    html = send(:board_column_counts_tag, @board)

    # First count should be awaiting triage (no color style)
    first_count = html.match(/<span class="board-menu-count">(\d+)<\/span>/)
    assert first_count, "Should have a count without color for awaiting triage"
    assert_equal @board.cards.awaiting_triage.count.to_s, first_count[1]
  end

  test "board_column_counts_tag shows column counts with colors" do
    html = send(:board_column_counts_tag, @board)

    @board.columns.sorted.each do |column|
      assert_match "--card-color: #{column.color};", html
    end
  end

  test "board_column_counts_tag returns empty span when no columns and no cards" do
    board = Board.new
    board.define_singleton_method(:columns) { Column.none }
    board.define_singleton_method(:cards) { Card.none }

    html = send(:board_column_counts_tag, board)

    assert_equal "<span></span>", html
  end

  test "board_count_tag formats count over 99 as 99+" do
    html = send(:board_count_tag, 150)

    assert_match "99+", html
  end

  test "board_count_tag includes color style when provided" do
    html = send(:board_count_tag, 5, color: "var(--color-card-3)")

    assert_match "--card-color: var(--color-card-3);", html
  end

  test "board_count_tag omits style when no color provided" do
    html = send(:board_count_tag, 5)

    assert_no_match(/style=/, html)
  end
end
