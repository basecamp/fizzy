require "test_helper"

class Notifier::EventNotifierTest < ActiveSupport::TestCase
  test "for returns the matching notifier class for the mention" do
    assert_kind_of Notifier::MentionNotifier, Notifier.for(mentions(:logo_card_david_mention_by_jz))
  end

  test "notify the mentionee" do
    users(:kevin).mentioned_by(users(:david), at: cards(:logo))

    assert_no_difference -> { users(:kevin).notifications.count } do
      Notifier.for(mentions(:logo_card_david_mention_by_jz)).notify
    end
  end

  test "create notifications for mentionee" do
    assert_no_difference -> { users(:david).notifications.count } do
      Notifier.for(events(:layout_commented)).notify
    end
  end

  test "don't create notifications for self-mentions" do
    assert_no_difference -> { users(:jz).notifications.count } do
      Notifier.for(events(:layout_commented)).notify
    end
  end

  test "updates source_type correctly even when a concurrent job modifies it between load and save" do
    # Start with a notification sourced from a Mention for kevin on the layout card
    notifications(:layout_commented_kevin).destroy
    mention = users(:kevin).mentioned_by(users(:david), at: comments(:layout_overflowing_david))
    notification = Notification.create!(
      user: users(:kevin), card: cards(:layout),
      source: mention, creator: users(:david), unread_count: 1
    )

    # Override create_or_find_by to simulate a concurrent EventNotifier updating
    # source_type in the database after the notification is loaded but before
    # the MentionNotifier's update! runs — reproducing the race condition where
    # Rails' dirty tracking skips source_type because it hasn't changed from
    # the stale in-memory value.
    Notification.class_eval do
      class << self
        alias_method :original_create_or_find_by, :create_or_find_by

        def create_or_find_by(...)
          original_create_or_find_by(...).tap do |record|
            unless record.previously_new_record?
              where(id: record.id).update_all(source_type: "Event")
            end
          end
        end
      end
    end

    new_mention = users(:kevin).mentioned_by(users(:jz), at: comments(:layout_overflowing_david))
    Notifier.for(new_mention).notify

    notification.reload
    assert_equal "Mention", notification.source_type
    assert_equal new_mention, notification.source
  ensure
    Notification.class_eval do
      class << self
        alias_method :create_or_find_by, :original_create_or_find_by
        remove_method :original_create_or_find_by
      end
    end
  end
end
