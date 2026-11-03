require "application_system_test_case"

class BoardScrollTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  setup do
    sign_in_as(users(:david))
    Current.user = users(:kevin)

    @board = boards(:writebook)
    30.times { |i| @board.cards.create!(title: "Maybe #{i}", creator: users(:david), status: :published) }
  end

  test "clicking column headings doesn't jump back to the last hovered card" do
    visit board_url(@board)

    page.execute_script("window.scrollTo(0, document.scrollingElement.scrollHeight)")
    deep_card = all("#maybe .card", minimum: 15)[13]
    deep_card.hover
    assert_selector "##{deep_card[:id]}[aria-selected]"

    park_mouse
    page.execute_script("window.scrollTo(0, 0)")
    assert_board_scrolled_to_top

    # The column is expanded and its first card selected, without moving the board.
    column = columns(:writebook_in_progress)
    within("##{dom_id(column)}") { find("button.cards__expander").click }
    assert_selector "##{dom_id(column)}.is-expanded .card:focus"
    assert_board_scrolled_to_top

    # The Maybe? expander is disabled on desktop, so clicking it focuses the column and selects its last hovered card.
    click_at find("#maybe .cards__expander")
    assert_selector "#maybe .card:focus"
    assert_board_scrolled_to_top
    assert_selector "##{deep_card[:id]}:focus"
  end

  test "hovering a card doesn't scroll the board" do
    visit board_url(@board)

    park_mouse
    card = all("#maybe .card", minimum: 15)[8]
    page.execute_script(<<~JS, card)
      const card = arguments[0].getBoundingClientRect()
      window.scrollBy(0, card.bottom - window.innerHeight - card.height / 4)
    JS
    scroll_y = board_scroll_y
    assert scroll_y > 0
    assert page.evaluate_script("arguments[0].getBoundingClientRect().bottom > window.innerHeight", card), "The card should be cut off by the bottom of the window"

    hover_top_of(card)
    assert_selector "##{card[:id]}:focus"
    assert_equal scroll_y, board_scroll_y
  end

  test "clicking a column's empty space doesn't jump back to its last hovered card" do
    visit board_url(@board)

    deep_card = remember_deep_maybe_card

    header = find("#maybe .cards__header")
    x, y = page.evaluate_script("(rect => [ rect.left + 8, rect.top + rect.height / 2 ])(arguments[0].getBoundingClientRect())", header)
    assert page.evaluate_script("document.elementFromPoint(#{x}, #{y}) === arguments[0]", header), "Should click the heading's padding, not its buttons"

    page.driver.browser.action.move_to_location(x.round, y.round).click.perform
    assert_selector "##{deep_card[:id]}:focus"
    assert_board_scrolled_to_top
  end

  test "tabbing into a column scrolls to its last hovered card" do
    visit board_url(@board)

    deep_card = remember_deep_maybe_card

    # The Maybe? expander is disabled on desktop, so the column comes right before its maximize button.
    page.execute_script("arguments[0].focus({ preventScroll: true })", find("#maybe .cards__maximize-button", visible: :all))
    page.driver.browser.action.key_down(:shift).send_keys(:tab).key_up(:shift).perform
    assert_selector "##{deep_card[:id]}:focus"
    assert board_scroll_y > 0
    assert page.evaluate_script("(rect => rect.top >= 0 && Math.floor(rect.bottom) <= window.innerHeight)(arguments[0].getBoundingClientRect())", deep_card), "The card should be scrolled into view"
  end

  private
    def park_mouse
      page.driver.browser.action.move_to_location(1, 1).perform
    end

    # The bottom of the window is under the fixed bar, so point at the visible top of the card.
    def hover_top_of(element)
      x, y = page.evaluate_script("(rect => [ rect.left + rect.width / 2, rect.top + 10 ])(arguments[0].getBoundingClientRect())", element)
      page.driver.browser.action.move_to_location(x.round, y.round).perform
    end

    def remember_deep_maybe_card
      page.execute_script("window.scrollTo(0, document.scrollingElement.scrollHeight)")
      all("#maybe .card", minimum: 15)[13].tap do |card|
        card.hover
        assert_selector "##{card[:id]}[aria-selected]"

        park_mouse
        page.execute_script("window.scrollTo(0, 0)")
        assert_board_scrolled_to_top
      end
    end

    # Selenium refuses to click a disabled button, but a mouse can.
    def click_at(element)
      page.driver.browser.action.move_to(element.native).click.perform
    end

    def assert_board_scrolled_to_top
      assert_equal 0, board_scroll_y
      assert page.evaluate_script("document.querySelector('#maybe .cards__header').getBoundingClientRect().top >= 0"), "Maybe? heading is scrolled out of view"
    end

    def board_scroll_y
      page.evaluate_script("Math.round(document.scrollingElement.scrollTop)")
    end
end
