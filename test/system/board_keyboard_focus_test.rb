require "application_system_test_case"

class BoardKeyboardFocusTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  setup do
    sign_in_as(users(:david))
    Current.user = users(:kevin)
  end

  test "escaping from a card returns focus to it" do
    board = boards(:writebook)
    board.cards.create!(title: "Another maybe", creator: users(:david), status: :published)
    visit board_url(board)

    # A card in a column comes back focused, and it is the card that was opened, not the column's first.
    open_column columns(:writebook_triage)
    card = board.cards.find_by!(number: arrow_down_to_next_card)
    open_and_escape_from card
    assert_focused card

    # Maybe cards render inline rather than in a frame, so they connect before the list controller does.
    page.execute_script("document.getElementById('maybe').focus()")
    card = board.cards.find_by!(number: arrow_down_to_next_card)
    open_and_escape_from card
    assert_focused card

    # A card moved to a collapsed column while open is not focused, and the open column is left alone.
    card = cards(:text)
    open_column card.column
    assert_focused card
    open_and_escape_from(card) { card.triage_into columns(:writebook_review) }
    assert_selector "##{dom_id(columns(:writebook_in_progress))}.is-expanded"
    assert_selector "##{dom_id(columns(:writebook_review))}.is-collapsed"
    assert_no_selector "##{dom_id(card, :article)}[aria-selected]", visible: :all
  end

  private
    def open_column(column)
      within("##{dom_id(column)}") { find("button.cards__expander").click }
      page.execute_script("document.getElementById(arguments[0]).focus()", dom_id(column))
    end

    def arrow_down_to_next_card
      first_card = find(".card:focus")
      send_keys :down
      assert_no_selector "##{first_card[:id]}:focus"
      find(".card:focus")[:"data-id"]
    end

    def open_and_escape_from(card)
      send_keys :enter
      assert_selector "h1", text: card.title
      yield if block_given?
      send_keys :escape
      assert_current_path board_path(card.board)
    end

    def assert_focused(card)
      assert_selector "##{dom_id(card, :article)}:focus"
    end
end
