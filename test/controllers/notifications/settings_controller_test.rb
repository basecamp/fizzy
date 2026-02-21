require "test_helper"

class Notifications::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:david)

    sign_in_as @user
  end

  test "show" do
    get notifications_settings_path

    assert_response :success
  end

  test "show with registered devices" do
    @user.identity.devices.create!(token: "test_token", platform: "apple", name: "iPhone 15 Pro")

    get notifications_settings_path

    assert_response :success
  end

  test "update email frequency" do
    assert_changes -> { @user.reload.settings.bundle_email_frequency }, from: "never", to: "every_few_hours" do
      put notifications_settings_path, params: { user_settings: { bundle_email_frequency: "every_few_hours" } }
    end

    assert_redirected_to notifications_settings_path
    assert_equal "Settings updated", flash[:notice]
  end
end
