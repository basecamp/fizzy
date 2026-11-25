require "application_system_test_case"

class NotificationsTrayTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:kevin))
  end

  test "clearing all notifications keeps the tray working" do
    visit root_url
    send_keys "n"
    assert_selector "#notifications .tray__item--notification"

    click_on "Clear all"

    assert_no_selector "#notifications .tray__item--notification", visible: :all
    assert_no_selector "#notifications .turbo-frame-error", visible: :all
    assert_selector "turbo-frame#notifications[src$='/notifications/tray']", visible: :all
    assert_empty users(:kevin).notifications.unread

    # The tray reloads its frame from its src when the window regains focus
    execute_script "document.getElementById('notifications').reload()"

    assert_selector "turbo-frame#notifications[src$='/notifications/tray'][complete]", visible: :all
    assert_no_selector "#notifications .turbo-frame-error", visible: :all
  end
end
