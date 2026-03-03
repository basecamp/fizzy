require "test_helper"

class Notification::PushTarget::NativeTest < ActiveSupport::TestCase
  setup do
    @user = users(:kevin)
    @identity = @user.identity
    @notification = notifications(:logo_assignment_kevin)

    # Ensure user has no web push subscriptions (we want to test native push independently)
    @user.push_subscriptions.delete_all
  end

  test "payload category returns assignment for card_assigned" do
    notification = notifications(:logo_assignment_kevin)

    assert_equal "assignment", notification.payload.category
  end

  test "payload category returns comment for comment_created" do
    notification = notifications(:layout_commented_kevin)

    assert_equal "comment", notification.payload.category
  end

  test "payload category returns mention for mentions" do
    notification = notifications(:logo_mentioned_david)

    assert_equal "mention", notification.payload.category
  end

  test "payload category returns card for other card events" do
    @notification.update!(source: events(:logo_published))

    assert_equal "card", @notification.payload.category
  end


  test "pushes to native devices when user has devices" do
    stub_push_services
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    assert_native_push_delivery(count: 1) do
      Notification::PushTarget::Native.new(@notification).process
    end
  end

  test "does not push when user has no devices" do
    @identity.devices.delete_all

    assert_no_native_push_delivery do
      Notification::PushTarget::Native.new(@notification).process
    end
  end

  test "pushes to multiple devices" do
    stub_push_services
    @identity.devices.delete_all
    @identity.devices.create!(token: "token1", platform: "apple", name: "iPhone")
    @identity.devices.create!(token: "token2", platform: "google", name: "Pixel")

    assert_native_push_delivery(count: 2) do
      Notification::PushTarget::Native.new(@notification).process
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

  test "native notification sets high_priority for mentions" do
    notification = notifications(:logo_mentioned_david)
    notification.user.identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(notification)
    native = push.send(:native_notification)

    assert native.high_priority
  end

  test "native notification sets normal priority for comments" do
    notification = notifications(:layout_commented_kevin)
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(notification)
    native = push.send(:native_notification)

    assert_not native.high_priority
  end

  test "native notification sets normal priority for other card events" do
    @notification.update!(source: events(:logo_published))
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
    assert_not_nil native.apple_data.dig(:aps, :category)
  end

  test "native notification sets time-sensitive interruption level for assignments" do
    notification = notifications(:logo_assignment_kevin)
    notification.user.identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(notification)
    native = push.send(:native_notification)

    assert_equal "time-sensitive", native.apple_data.dig(:aps, :"interruption-level")
  end

  test "native notification sets time-sensitive interruption level for mentions" do
    notification = notifications(:logo_mentioned_david)
    notification.user.identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(notification)
    native = push.send(:native_notification)

    assert_equal "time-sensitive", native.apple_data.dig(:aps, :"interruption-level")
  end

  test "native notification sets active interruption level for comments" do
    notification = notifications(:layout_commented_kevin)
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(notification)
    native = push.send(:native_notification)

    assert_equal "active", native.apple_data.dig(:aps, :"interruption-level")
  end

  test "native notification sets active interruption level for other card events" do
    @notification.update!(source: events(:logo_published))
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(@notification)
    native = push.send(:native_notification)

    assert_equal "active", native.apple_data.dig(:aps, :"interruption-level")
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
    assert_equal @notification.account.id, native.data[:account_id]
    assert_equal @notification.account.slug, native.data[:account_slug]
    assert_equal @notification.creator.name, native.data[:creator_name]
  end

  test "native notification includes base_url without account slug" do
    @identity.devices.create!(token: "test123", platform: "apple", name: "Test iPhone")

    push = Notification::PushTarget::Native.new(@notification)
    native = push.send(:native_notification)

    assert_equal "http://example.com", native.data[:base_url]
  end

  private
    def assert_native_push_delivery(count: 1, &block)
      assert_enqueued_jobs count, only: ApplicationPushNotificationJob do
        perform_enqueued_jobs only: Notification::PushJob, &block
      end
    end

    def assert_no_native_push_delivery(&block)
      assert_enqueued_jobs 0, only: ApplicationPushNotificationJob do
        perform_enqueued_jobs only: Notification::PushJob, &block
      end
    end

    def stub_push_services
      ActionPushNative.stubs(:service_for).returns(stub(push: true))
    end
end
