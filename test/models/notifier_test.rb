require "test_helper"

class NotifierTest < ActiveSupport::TestCase
  test "for returns the matching notifier class for the event" do
    assert_kind_of Notifier::Published, Notifier.for(events(:logo_published))
  end

  test "for does not raise an error when the event is not notifiable" do
    assert_nothing_raised do
      assert_no_difference -> { Notification.count } do
        Notifier.for(events(:logo_boost_dhh))
      end
    end
  end

  test "generate does not create notifications if the event was system-generated" do
    cards(:logo).drafted!
    events(:logo_published).update!(creator: accounts("37s").users.system)

    assert_no_difference -> { Notification.count } do
      Notifier.for(events(:logo_published)).generate
    end
  end

  test "creates a notification for each watcher, other than the event creator" do
    notifications = Notifier.for(events(:layout_commented)).generate

    assert_equal [ users(:kevin) ], notifications.map(&:user)
  end

  test "does not create a notification for access-only users" do
    collections(:writebook).access_for(users(:kevin)).access_only!

    notifications = Notifier.for(events(:layout_commented)).generate

    assert_equal [ users(:kevin) ], notifications.map(&:user)
  end

  test "the published event creates notifications for subscribers as well as watchers" do
    notifications = Notifier.for(events(:logo_published)).generate

    assert_equal users(:kevin, :jz).sort, notifications.map(&:user).sort
  end

  test "links to the card" do
    Notifier.for(events(:logo_published)).generate

    assert_equal cards(:logo), Notification.last.resource
  end

  test "assignment events only create a notification for the assignee" do
    collections(:writebook).access_for(users(:jz)).watching!
    collections(:writebook).access_for(users(:kevin)).everything!

    notifications = Notifier.for(events(:logo_assignment_jz)).generate

    assert_equal [ users(:jz) ], notifications.map(&:user)
  end

  test "assignment events do not notify users who are access-only for the collection" do
    collections(:writebook).access_for(users(:jz)).access_only!

    notifications = Notifier.for(events(:logo_assignment_jz)).generate

    assert_empty notifications
  end
end
