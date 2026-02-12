require "test_helper"

class NotificationPusherTest < ActiveSupport::TestCase
  setup do
    @user = users(:david)
    @notification = notifications(:logo_mentioned_david)
    @pusher = NotificationPusher.new(@notification)

    @user.push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/test123",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )
  end

  test "push does not send notifications for cancelled accounts" do
    @user.account.cancel(initiated_by: @user)

    result = @pusher.push

    assert_nil result, "Should not push notifications for cancelled accounts"
  end

  test "push sends notifications for active accounts with subscriptions" do
    result = @pusher.push

    assert_not_nil result, "Should push notifications for active accounts with subscriptions"
  end
end
