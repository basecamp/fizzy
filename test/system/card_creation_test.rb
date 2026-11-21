require "application_system_test_case"

class CardCreationTest < ApplicationSystemTestCase
  test "creating a card with the keyboard shortcut publishes the title typed last" do
    sign_in_as(users(:david))

    visit board_url(boards(:writebook))
    click_on "Add a card"
    fill_in "card_title", with: "Published with a shortcut"
    find("#card_title").send_keys [ :control, :enter ]

    assert_selector "h3", text: "Published with a shortcut"

    card = boards(:writebook).cards.order(:created_at).last
    assert_equal "Published with a shortcut", card.title
    assert_empty card.events.where(action: "card_title_changed"),
      "Publishing an untitled card and renaming it afterwards leaks a title change"
  end
end
