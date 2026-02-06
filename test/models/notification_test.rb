require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "unread marks notification as unread" do
    notification = notifications(:logo_published_kevin)
    notification.read # Mark as read first

    assert_changes -> { notification.reload.read? }, from: true, to: false do
      notification.unread
    end
  end

  test "unread broadcasts to notifications" do
    notification = notifications(:logo_published_kevin)
    notification.read # Mark as read first

    assert_turbo_stream_broadcasts([ notification.user, :notifications ], count: 1) do
      perform_enqueued_jobs do
        notification.unread
      end
    end
  end

  test "read marks notification as read" do
    notification = notifications(:logo_published_kevin)
    # Ensure it starts as unread
    notification.update!(read_at: nil)

    assert_changes -> { notification.reload.read? }, from: false, to: true do
      notification.read
    end
  end

  test "read broadcasts to notifications" do
    notification = notifications(:logo_published_kevin)
    # Ensure it starts as unread
    notification.update!(read_at: nil)

    assert_turbo_stream_broadcasts([ notification.user, :notifications ], count: 1) do
      notification.read
    end
  end

  test "deleting notification broadcasts its removal" do
    notification = notifications(:logo_published_kevin)
    notification.update!(read_at: nil)

    assert_turbo_stream_broadcasts([ notification.user, :notifications ], count: 1) do
      notification.destroy
    end
  end
end
