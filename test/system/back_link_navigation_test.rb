require "application_system_test_case"

class BackLinkNavigationTest < ApplicationSystemTestCase
  test "card back link returns to board filter view when navigating from it" do
    sign_in_as(users(:david))

    filter_url = board_url(boards(:writebook), creator_ids: [ users(:david).id ])
    visit filter_url
    click_on cards(:logo).title

    back_link = find("a.btn--back")
    assert_selector "a.btn--back strong", text: "Back to Writebook"
    back_link.click
    assert_current_path filter_url, ignore_query: false
  end

  test "card back link returns to global filter view when navigating from it" do
    sign_in_as(users(:kevin))

    filter_url = cards_url(creator_ids: [ users(:kevin).id ])
    visit filter_url
    click_on cards(:text).title

    assert_selector "a.btn--back strong", text: "Back to all boards"
    find("a.btn--back").click
    assert_current_path filter_url, ignore_query: false
  end

  test "card back link returns to activity page when navigating from it" do
    sign_in_as(users(:david))

    assert_text "Layout is broken"
    click_on "Layout is broken"

    assert_selector "a.btn--back strong", text: "Back to Home"
    find("a.btn--back").click
    assert_current_path root_path
  end

  test "card back link returns to activity page when navigating from it without trailing slash" do
    sign_in_as(users(:david))

    activity_url_without_trailing_slash = root_url.chomp("/")
    visit activity_url_without_trailing_slash
    assert_text "Layout is broken"
    click_on "Layout is broken"

    assert_selector "a.btn--back strong", text: "Back to Home"
    find("a.btn--back").click
    assert_current_path activity_url_without_trailing_slash
  end

  test "card back link is not rewritten when navigating from a non-filter page" do
    sign_in_as(users(:david))

    visit account_settings_url
    click_on "Invite people"
    visit card_url(cards(:logo))

    assert_selector "a.btn--back strong", text: "Back to Writebook"
  end
end
