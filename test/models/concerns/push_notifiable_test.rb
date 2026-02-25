require "test_helper"

class PushNotifiableTest < ActiveSupport::TestCase
  test "enqueues push notification job when notification is created" do
    assert_enqueued_with(job: PushNotificationJob) do
      users(:david).notifications.create!(
        source: events(:layout_published),
        creator: users(:jason)
      )
    end
  end

  test "enqueues push notification job when notification source changes" do
    notification = notifications(:logo_mentioned_david)

    assert_enqueued_with(job: PushNotificationJob) do
      notification.update!(source: events(:logo_published))
    end
  end

  test "does not enqueue push notification job for other updates" do
    notification = notifications(:logo_mentioned_david)

    assert_no_enqueued_jobs only: PushNotificationJob do
      notification.update!(unread_count: 5)
    end
  end
end
