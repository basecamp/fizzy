require "test_helper"

class NotificationDeliveryTest < ActiveSupport::TestCase
  setup do
    @assigner = users(:david)
    @assignee = users(:kevin)
    @card = cards(:logo)

    @card.assignments.destroy_all
    @assignee.notifications.destroy_all

    stub_web_push_pool

    @original_targets = Notification.push_targets.dup
    Notification.push_targets = []
    Notification.register_push_target(:web)
    Notification.register_push_target(push_target_with_tracking)

    # Give assignee a web push subscription
    @assignee.push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/test123",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    Current.user = @assigner
  end

  teardown do
    Notification.push_targets = @original_targets
    @assignee.push_subscriptions.delete_all
  end

  test "card assignment creates notification and triggers push" do
    assert_difference -> { Notification.count }, 1 do
      perform_enqueued_jobs only: [ NotifyRecipientsJob, Notification::PushJob ] do
        @card.toggle_assignment(@assignee)
      end
    end

    notification = Notification.last
    assert_equal @assignee, notification.user
    assert_equal @assigner, notification.creator
    assert_equal "card_assigned", notification.source.action

    assert_push_delivered_for notification
    assert_web_push_delivered
  end

  test "card assignment notification is bundled for email delivery when bundling enabled" do
    @assignee.settings.update!(bundle_email_frequency: :every_few_hours)

    assert_difference -> { Notification.count }, 1 do
      perform_enqueued_jobs only: NotifyRecipientsJob do
        @card.toggle_assignment(@assignee)
      end
    end

    notification = @assignee.notifications.reload.last
    assert_not_nil notification, "Notification should be created for assignee"

    bundle = @assignee.notification_bundles.pending.last
    assert_not_nil bundle, "Bundle should be created when bundling is enabled"
    assert_includes bundle.notifications, notification
  end

  test "comment creates notification for card watchers and triggers push" do
    @card.watch_by(@assignee)

    assert_difference -> { Notification.count }, 1 do
      perform_enqueued_jobs only: [ NotifyRecipientsJob, Notification::PushJob ] do
        @card.comments.create!(body: "Great work on this!", creator: @assigner)
      end
    end

    notification = Notification.last
    assert_equal @assignee, notification.user
    assert_equal "comment_created", notification.source.action

    assert_push_delivered
    assert_web_push_delivered
  end

  test "mention creates notification and triggers push" do
    mention_html = ActionText::Attachment.from_attachable(@assignee).to_html

    perform_enqueued_jobs only: [ Mention::CreateJob, NotifyRecipientsJob, Notification::PushJob ] do
      @card.comments.create!(
        body: "#{mention_html} check this out",
        creator: @assigner
      )
    end

    mention_notification = @assignee.notifications.find_by(source_type: "Mention")
    assert_not_nil mention_notification

    assert_push_delivered_for mention_notification
    assert_web_push_delivered
  end

  test "system user actions do not create notifications" do
    Current.user = users(:system)

    assert_no_difference -> { Notification.count } do
      perform_enqueued_jobs only: [ NotifyRecipientsJob, Notification::PushJob ] do
        @card.toggle_assignment(@assignee)
      end
    end

    assert_no_push_delivered
    assert_no_web_push_delivered
  end

  test "notifications for inactive users are created but do not trigger push" do
    @assignee.deactivate

    assert_difference -> { Notification.count }, 1 do
      perform_enqueued_jobs only: [ NotifyRecipientsJob, Notification::PushJob ] do
        @card.toggle_assignment(@assignee)
      end
    end

    assert_no_push_delivered
    assert_no_web_push_delivered
  end

  private
    def stub_web_push_pool
      @web_push_calls = []
      web_push_pool = stub("web_push_pool")
      web_push_pool.stubs(:queue).with do |payload, subs|
        @web_push_calls << { payload: payload, subscriptions: subs }
      end

      Rails.configuration.x.stubs(:web_push_pool).returns(web_push_pool)
    end

    def push_target_with_tracking
      @push_target_calls = []
      fake_push_target = Class.new(Notification::PushTarget) do
        class << self
          attr_accessor :calls
        end

        def self.process(notification)
          calls << notification
        end
      end

      fake_push_target.tap { it.calls = @push_target_calls }
    end

    def assert_push_delivered
      assert_not_empty @push_target_calls, "Expected push to be delivered"
    end

    def assert_push_delivered_for(notification)
      assert_includes @push_target_calls, notification, "Expected push to be delivered for notification"
    end

    def assert_no_push_delivered
      assert_empty @push_target_calls, "Expected no push to be delivered"
    end

    def assert_web_push_delivered
      assert_not_empty @web_push_calls, "Expected web push to be delivered"
    end

    def assert_no_web_push_delivered
      assert_empty @web_push_calls, "Expected no web push to be delivered"
    end
end
