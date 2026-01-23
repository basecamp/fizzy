require "test_helper"

class PushConfigTest < ActiveSupport::TestCase
  test "loads push config from the saas engine" do
    skip unless Fizzy.saas?

    config = ActionPushNative.config

    apple_team_id = config.dig(:apple, :team_id)
    apple_topic = config.dig(:apple, :topic)
    google_project_id = config.dig(:google, :project_id)

    skip "Update test once APNS team_id is configured" if apple_team_id == "YOUR_TEAM_ID"
    skip "Update test once APNS topic is configured" if apple_topic == "com.yourcompany.fizzy"
    skip "Update test once FCM project_id is configured" if google_project_id == "your-firebase-project"

    assert apple_team_id.present?
    assert apple_topic.present?
    assert google_project_id.present?
  end
end
