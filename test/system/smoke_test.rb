require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  test "dismissing notifications" do
    sign_in_as(users(:david))

    notification = notifications(:logo_mentioned_david)

    assert_selector "div##{dom_id(notification)}"

    within_window(open_new_window) { visit card_url(notification.card) }

    assert_no_selector "div##{dom_id(notification)}"
  end

  test "dragging card to a new column" do
    sign_in_as(users(:david))

    card = Card.find("03axhd1h3qgnsffqplkyf28fv")
    assert_nil(card.column)

    visit board_url(boards(:writebook))

    card_el = page.find("#article_card_03axhd1h3qgnsffqplkyf28fv")
    column_el = page.find("#column_03axmcferfmbnv4qg816nw6bg")
    cards_count = column_el.find(".cards__expander-count").text.to_i

    card_el.drag_to(column_el)

    column_el.find(".cards__expander-count", text: cards_count + 1)
    assert_equal("Triage", card.reload.column.name)
  end
end
