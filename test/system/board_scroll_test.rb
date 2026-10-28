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
      window.scrollBy(0, card.bottom - window.innerHeight + card.height / 4)
    JS
    scroll_y = board_scroll_y
    assert scroll_y > 0, "The card should be cut off by the bottom of the window"

    card.hover
    assert_selector "##{card[:id]}:focus"
    assert_equal scroll_y, board_scroll_y
  end

  private
    def park_mouse
      page.driver.browser.action.move_to_location(1, 1).perform
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
