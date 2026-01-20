require "test_helper"

class NotificationPusherNativeTest < ActiveSupport::TestCase
  setup do
    @user = users(:kevin)
    @notification = notifications(:logo_published_kevin)
    @pusher = NotificationPusher.new(@notification)

    # Ensure user has no web push subscriptions (we want to test native push independently)
    @user.push_subscriptions.delete_all
  end

  # === Notification Category ===

  test "notification_category returns assignment for card_assigned" do
    notification = notifications(:logo_assignment_kevin)
    pusher = NotificationPusher.new(notification)

    assert_equal "assignment", pusher.send(:notification_category)
  end

  test "notification_category returns comment for comment_created" do
    notification = notifications(:layout_commented_kevin)
    pusher = NotificationPusher.new(notification)

    assert_equal "comment", pusher.send(:notification_category)
  end

  test "notification_category returns mention for mentions" do
    notification = notifications(:logo_card_david_mention_by_jz)
    pusher = NotificationPusher.new(notification)

    assert_equal "mention", pusher.send(:notification_category)
  end

  test "notification_category returns card for other card events" do
    notification = notifications(:logo_published_kevin)
    pusher = NotificationPusher.new(notification)

    assert_equal "card", pusher.send(:notification_category)
  end

  # === Interruption Level ===

  test "interruption_level is time-sensitive for assignments" do
    notification = notifications(:logo_assignment_kevin)
    pusher = NotificationPusher.new(notification)

    assert_equal "time-sensitive", pusher.send(:interruption_level)
  end

  test "interruption_level is active for non-assignments" do
    notification = notifications(:logo_published_kevin)
    pusher = NotificationPusher.new(notification)

    assert_equal "active", pusher.send(:interruption_level)
  end

  # === Has Any Push Destination ===

  test "push_destination returns true when user has native devices" do
    @user.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    assert @pusher.send(:push_destination?)
  end

  test "push_destination returns true when user has web subscriptions" do
    @user.push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/test",
      p256dh_key: "test_p256dh",
      auth_key: "test_auth"
    )

    assert @pusher.send(:push_destination?)
  end

  test "push_destination returns false when user has neither" do
    @user.devices.delete_all
    @user.push_subscriptions.delete_all

    assert_not @pusher.send(:push_destination?)
  end

  # === Push Delivery ===

  test "push delivers to native devices when user has devices" do
    stub_push_services
    @user.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    assert_native_push_delivery(count: 1) do
      @pusher.push
    end
  end

  test "push does not deliver to native when user has no devices" do
    @user.devices.delete_all

    assert_no_native_push_delivery do
      @pusher.push
    end
  end

  test "push does not deliver when creator is system user" do
    stub_push_services
    @user.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")
    @notification.update!(creator: users(:system))

    result = @pusher.push

    assert_nil result
  end

  test "push delivers to multiple devices" do
    stub_push_services
    @user.devices.delete_all
    @user.devices.create!(token: "token1", platform: "apple", name: "iPhone")
    @user.devices.create!(token: "token2", platform: "google", name: "Pixel")

    assert_native_push_delivery(count: 2) do
      @pusher.push
    end
  end

  test "push delivers to both web and native when user has both" do
    stub_push_services

    # Set up web push subscription
    @user.push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/test",
      p256dh_key: "test_p256dh_key",
      auth_key: "test_auth_key"
    )

    # Set up native device
    @user.devices.create!(token: "native_token", platform: "apple", name: "iPhone")

    # Mock web push pool to verify it receives the payload
    web_push_pool = mock("web_push_pool")
    web_push_pool.expects(:queue).once.with do |payload, subscriptions|
      payload.is_a?(Hash) && subscriptions.count == 1
    end
    Rails.configuration.x.stubs(:web_push_pool).returns(web_push_pool)

    # Verify native push is also delivered
    assert_native_push_delivery(count: 1) do
      @pusher.push
    end
  end

  # === Native Notification Building ===

  test "native notification includes required fields" do
    @user.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")
    payload = @pusher.send(:build_payload)
    native = @pusher.send(:native_notification, payload)

    assert_not_nil native.title
    assert_not_nil native.body
    assert_equal "default", native.sound
  end

  test "native notification sets thread_id from card" do
    @user.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")
    payload = @pusher.send(:build_payload)
    native = @pusher.send(:native_notification, payload)

    assert_equal @notification.card.id, native.thread_id
  end

  test "native notification sets high_priority for assignments" do
    notification = notifications(:logo_assignment_kevin)
    notification.user.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")
    pusher = NotificationPusher.new(notification)

    payload = pusher.send(:build_payload)
    native = pusher.send(:native_notification, payload)

    assert native.high_priority
  end

  test "native notification sets normal priority for non-assignments" do
    @user.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")
    payload = @pusher.send(:build_payload)
    native = @pusher.send(:native_notification, payload)

    assert_not native.high_priority
  end

  # === Apple-specific Payload ===

  test "native notification includes apple-specific fields" do
    @user.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")
    payload = @pusher.send(:build_payload)
    native = @pusher.send(:native_notification, payload)

    assert_equal 1, native.apple_data.dig(:aps, :"mutable-content")
    assert_includes %w[active time-sensitive], native.apple_data.dig(:aps, :"interruption-level")
    assert_not_nil native.apple_data.dig(:aps, :category)
  end

  # === Google-specific Payload ===

  test "native notification sets android notification to nil for data-only" do
    @user.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")
    payload = @pusher.send(:build_payload)
    native = @pusher.send(:native_notification, payload)

    assert_nil native.google_data.dig(:android, :notification)
  end

  # === Data Payload ===

  test "native notification includes data payload" do
    @user.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")
    payload = @pusher.send(:build_payload)
    native = @pusher.send(:native_notification, payload)

    assert_not_nil native.data[:url]
    assert_equal @notification.account.external_account_id, native.data[:account_id]
    assert_equal @notification.creator.name, native.data[:creator_name]
  end
end
