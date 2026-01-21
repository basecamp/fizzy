require "test_helper"

class Notification::PushTarget::WebTest < ActiveSupport::TestCase
  setup do
    @user = users(:david)
    @notification = @user.notifications.create!(
      source: events(:logo_published),
      creator: users(:jason)
    )

    @user.push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/test123",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    @web_push_pool = mock("web_push_pool")
    Rails.configuration.x.stubs(:web_push_pool).returns(@web_push_pool)
  end

  test "pushes to web when user has subscriptions" do
    @web_push_pool.expects(:queue).once.with do |payload, subscriptions|
      payload.is_a?(Hash) &&
        payload[:title].present? &&
        payload[:body].present? &&
        payload[:url].present? &&
        subscriptions.count == 1
    end

    Notification::PushTarget::Web.new(@notification).push
  end

  test "does not push when user has no subscriptions" do
    @user.push_subscriptions.delete_all
    @web_push_pool.expects(:queue).never

    Notification::PushTarget::Web.new(@notification).push
  end

  test "does not push for cancelled accounts" do
    @user.account.cancel(initiated_by: @user)
    @web_push_pool.expects(:queue).never

    Notification::PushTarget::Web.new(@notification).push
  end

  test "does not push when creator is system user" do
    @notification.update!(creator: users(:system))
    @web_push_pool.expects(:queue).never

    Notification::PushTarget::Web.new(@notification).push
  end

  test "payload includes card title for card events" do
    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:title] == @notification.card.title
    end

    Notification::PushTarget::Web.new(@notification).push
  end

  test "payload for comment includes RE prefix" do
    event = events(:layout_commented)
    notification = @user.notifications.create!(source: event, creator: event.creator)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:title].start_with?("RE:")
    end

    Notification::PushTarget::Web.new(notification).push
  end

  test "payload for assignment includes assigned message" do
    event = events(:logo_assignment_david)
    notification = @user.notifications.create!(source: event, creator: event.creator)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body].include?("Assigned to you")
    end

    Notification::PushTarget::Web.new(notification).push
  end

  test "payload for mention includes mentioner name" do
    mention = mentions(:logo_card_david_mention_by_jz)
    notification = @user.notifications.create!(source: mention, creator: users(:jz))

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:title].include?("mentioned you")
    end

    Notification::PushTarget::Web.new(notification).push
  end

  test "push_later enqueues Notification::WebPushJob" do
    assert_enqueued_with(job: Notification::WebPushJob, args: [ @notification ]) do
      Notification::PushTarget::Web.push_later(@notification)
    end
  end
end
