require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "read marks notification as read" do
    notification = notifications(:logo_assignment_kevin)
    notification.update!(read_at: nil, unread_count: 2)

    assert_changes -> { notification.reload.read? }, from: false, to: true do
      notification.read
    end

    assert_equal 0, notification.unread_count
  end

  test "unread marks notification as unread" do
    notification = notifications(:logo_assignment_kevin)
    notification.read

    assert_changes -> { notification.reload.read? }, from: true, to: false do
      notification.unread
    end

    assert_equal 1, notification.unread_count
  end

  test "read_all marks all notifications and resets unread counts" do
    kevin = users(:kevin)

    kevin.notifications.unread.read_all

    assert kevin.notifications.reload.all?(&:read?)
    assert kevin.notifications.reload.all? { |n| n.unread_count == 0 }
  end

  test "unread_count tracks notification count per card" do
    notification = notifications(:logo_assignment_kevin)
    assert_equal 2, notification.unread_count
  end

  test "broadcasting on create prepends" do
    kevin = users(:kevin)
    layout = cards(:layout)

    notifications(:layout_commented_kevin).destroy

    perform_enqueued_jobs do
      Notification.create!(user: kevin, source: events(:layout_commented), creator: users(:david))
    end

    assert_turbo_stream_broadcasts [ kevin, :notifications ]
  end

  test "broadcasting on update when read removes" do
    notification = notifications(:layout_commented_kevin)

    assert_turbo_stream_broadcasts([ notification.user, :notifications ], count: 1) do
      perform_enqueued_jobs do
        notification.read
      end
    end
  end

  test "broadcasting on destroy removes" do
    notification = notifications(:logo_assignment_kevin)

    assert_turbo_stream_broadcasts([ notification.user, :notifications ], count: 1) do
      notification.destroy
    end
  end
end
