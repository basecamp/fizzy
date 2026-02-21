require "test_helper"

class Notification::PushTarget::WebTest < ActiveSupport::TestCase
  setup do
    @user = users(:david)
    @notification = notifications(:logo_mentioned_david)

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

    Notification::PushTarget::Web.new(@notification).process
  end

  test "does not push when user has no subscriptions" do
    @user.push_subscriptions.delete_all
    @web_push_pool.expects(:queue).never

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload includes card title for card events" do
    @notification.update!(source: events(:logo_published))

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:title] == @notification.card.title
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for comment includes RE prefix" do
    event = events(:layout_commented)
    notification = @user.notifications.create!(source: event, creator: event.creator)

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:title].start_with?("RE:")
    end

    Notification::PushTarget::Web.new(notification).process
  end

  test "payload for assignment includes assigned message" do
    @notification.update!(source: events(:logo_assignment_david))

    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:body].include?("Assigned to you")
    end

    Notification::PushTarget::Web.new(@notification).process
  end

  test "payload for mention includes mentioner name" do
    @web_push_pool.expects(:queue).once.with do |payload, _|
      payload[:title].include?("mentioned you")
    end

    Notification::PushTarget::Web.new(@notification).process
  end
end
