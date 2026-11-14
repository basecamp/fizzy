require "test_helper"

class BackLinkNavigationInteractionTest < RailsJsdom::TestCase
  test "card back link returns to board filter view when navigating from it" do
    sign_in_as(users(:david))

    filter_path = board_path(boards(:writebook), creator_ids: [ users(:david).id ])
    visit filter_path
    click_on cards(:logo).title

    assert_selector "a.btn--back strong", text: "Back to Writebook"
    find("a.btn--back").click
    assert_current_path filter_path, ignore_query: false
  end

  test "card back link returns to global filter view when navigating from it" do
    sign_in_as(users(:kevin))

    filter_path = cards_path(creator_ids: [ users(:kevin).id ])
    visit filter_path
    click_on cards(:text).title

    assert_selector "a.btn--back strong", text: "Back to all boards"
    find("a.btn--back").click
    assert_current_path filter_path, ignore_query: false
  end

  test "card back link returns to activity page when navigating from it" do
    travel_to events(:layout_assignment_jz).created_at
    sign_in_as(users(:david))
    visit root_path

    assert_text "Layout is broken"
    click_on "Layout is broken"

    assert_selector "a.btn--back strong", text: "Back to Home"
    find("a.btn--back").click
    assert_current_path root_path
  end

  test "card back link returns to activity page when navigating from it without trailing slash" do
    travel_to events(:layout_assignment_jz).created_at
    sign_in_as(users(:david))

    activity_path_without_trailing_slash = root_path.chomp("/")
    visit activity_path_without_trailing_slash
    assert_text "Layout is broken"
    click_on "Layout is broken"

    assert_selector "a.btn--back strong", text: "Back to Home"
    find("a.btn--back").click
    assert_current_path activity_path_without_trailing_slash
  end

  test "card back link is not rewritten when navigating from a non-filter page" do
    sign_in_as(users(:david))

    visit account_settings_path
    click_on "Invite people"
    visit card_path(cards(:logo))

    assert_selector "a.btn--back strong", text: "Back to Writebook"
  end
end
