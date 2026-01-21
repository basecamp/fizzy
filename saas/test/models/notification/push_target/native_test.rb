require "test_helper"

class Notification::PushTarget::NativeTest < ActiveSupport::TestCase
  setup do
    @user = users(:kevin)
    @identity = @user.identity
    @notification = notifications(:logo_published_kevin)

    # Ensure user has no web push subscriptions (we want to test native push independently)
    @user.push_subscriptions.delete_all
  end

  test "notification_category returns assignment for card_assigned" do
    notification = notifications(:logo_assignment_kevin)
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(notification)

    assert_equal "assignment", push.send(:notification_category)
  end

  test "notification_category returns comment for comment_created" do
    notification = notifications(:layout_commented_kevin)
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(notification)

    assert_equal "comment", push.send(:notification_category)
  end

  test "notification_category returns mention for mentions" do
    notification = notifications(:logo_card_david_mention_by_jz)
    notification.user.identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(notification)

    assert_equal "mention", push.send(:notification_category)
  end

  test "notification_category returns card for other card events" do
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(@notification)

    assert_equal "card", push.send(:notification_category)
  end

  test "interruption_level is time-sensitive for assignments" do
    notification = notifications(:logo_assignment_kevin)
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(notification)

    assert_equal "time-sensitive", push.send(:interruption_level)
  end

  test "interruption_level is active for non-assignments" do
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(@notification)

    assert_equal "active", push.send(:interruption_level)
  end

  test "pushes to native devices when user has devices" do
    stub_push_services
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    assert_native_push_delivery(count: 1) do
      Notification::PushTarget::Native.new(@notification).push
    end
  end

  test "does not push when user has no devices" do
    @identity.devices.delete_all

    assert_no_native_push_delivery do
      Notification::PushTarget::Native.new(@notification).push
    end
  end

  test "does not push when creator is system user" do
    stub_push_services
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")
    @notification.update!(creator: users(:system))

    assert_no_native_push_delivery do
      Notification::PushTarget::Native.new(@notification).push
    end
  end

  test "pushes to multiple devices" do
    stub_push_services
    @identity.devices.delete_all
    @identity.devices.create!(token: "token1", platform: "apple", name: "iPhone")
    @identity.devices.create!(token: "token2", platform: "google", name: "Pixel")

    assert_native_push_delivery(count: 2) do
      Notification::PushTarget::Native.new(@notification).push
    end
  end

  test "native notification includes required fields" do
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(@notification)
    native = push.send(:native_notification)

    assert_not_nil native.title
    assert_not_nil native.body
    assert_equal "default", native.sound
  end

  test "native notification sets thread_id from card" do
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(@notification)
    native = push.send(:native_notification)

    assert_equal @notification.card.id, native.thread_id
  end

  test "native notification sets high_priority for assignments" do
    notification = notifications(:logo_assignment_kevin)
    notification.user.identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(notification)
    native = push.send(:native_notification)

    assert native.high_priority
  end

  test "native notification sets normal priority for non-assignments" do
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(@notification)
    native = push.send(:native_notification)

    assert_not native.high_priority
  end

  test "native notification includes apple-specific fields" do
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(@notification)
    native = push.send(:native_notification)

    assert_equal 1, native.apple_data.dig(:aps, :"mutable-content")
    assert_includes %w[active time-sensitive], native.apple_data.dig(:aps, :"interruption-level")
    assert_not_nil native.apple_data.dig(:aps, :category)
  end

  test "native notification sets android notification to nil for data-only" do
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(@notification)
    native = push.send(:native_notification)

    assert_nil native.google_data.dig(:android, :notification)
  end

  test "native notification includes data payload" do
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(@notification)
    native = push.send(:native_notification)

    assert_not_nil native.data[:url]
    assert_equal @notification.account.external_account_id, native.data[:account_id]
    assert_equal @notification.creator.name, native.data[:creator_name]
  end

  test "push_later enqueues Notification::NativePushJob" do
    assert_enqueued_with(job: Notification::NativePushJob, args: [ @notification ]) do
      Notification::PushTarget::Native.push_later(@notification)
    end
  end
end
