require "application_system_test_case"

class CardNavigationTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:david))
    Current.session = sessions(:david)
    @board = boards(:writebook)
    @column = columns(:writebook_review)
    @cards = 3.times.map do |i|
      @board.cards.create!(title: "Navigation #{i}", column: @column, status: :published, last_active_at: i.minutes.ago)
    end
  end

  test "buttons and keyboard navigate without wrapping and Esc returns to the board" do
    visit board_url(@board)
    visit card_url(@cards.first)
    assert_selector "button[aria-label='Previous card in column'][disabled]"
    assert_selector "button[aria-label='Next card in column']:not([disabled])"

    find("button[aria-label='Next card in column']").click
    assert_current_path card_path(@cards.second)
    send_keys [ :shift, :down ]
    assert_current_path card_path(@cards.last)
    assert_selector "button[aria-label='Next card in column'][disabled]"

    send_keys [ :shift, :up ]
    assert_current_path card_path(@cards.second)
    find("button[aria-label='Previous card in column']").click
    assert_current_path card_path(@cards.first)

    send_keys :escape
    assert_current_path board_path(@board)
  end

  test "activity changes do not reorder the browsing sequence and unavailable cards are skipped" do
    visit card_url(@cards.first)
    assert_selector "button[aria-label='Next card in column']:not([disabled])"
    @cards.last.touch_last_active_at
    @cards.second.close

    find("button[aria-label='Next card in column']").click
    assert_current_path card_path(@cards.last)
    find("button[aria-label='Previous card in column']").click
    assert_current_path card_path(@cards.first)
  end

  test "navigation does not interrupt editing or an open dialog" do
    visit card_url(@cards.first)
    assert_selector "button[aria-label='Next card in column']:not([disabled])"
    find("lexxy-editor").click
    send_keys [ :shift, :down ]
    assert_current_path card_path(@cards.first)

    page.execute_script("document.activeElement.blur(); const dialog = document.createElement('dialog'); document.body.append(dialog); dialog.showModal()")
    send_keys [ :shift, :down ]
    assert_current_path card_path(@cards.first)
  end

  test "closing the current card keeps navigation in the original column" do
    visit card_url(@cards.first)
    assert_selector "button[aria-label='Next card in column']:not([disabled])"
    find("button", text: "Mark as Done").click
    assert_text "Undo"

    find("button[aria-label='Next card in column']").click
    assert_current_path card_path(@cards.second)
    assert_selector "button[aria-label='Previous card in column'][disabled]"
  end
end
