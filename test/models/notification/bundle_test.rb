require "test_helper"

class Notification::BundleTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @user = users(:david)
    @user.notifications.destroy_all
    @user.settings.bundle_email_every_few_hours!
  end

  test "new notifications are bundled" do
    notification = assert_difference -> { @user.notification_bundles.pending.count }, 1 do
      @user.notifications.create!(source: events(:logo_published), creator: @user)
    end

    bundle = @user.notification_bundles.pending.last
    assert_includes bundle.notifications, notification
  end

  test "don't bundle new notifications if bundling is disabled" do
    @user.settings.bundle_email_never!

    assert_no_difference -> { @user.notification_bundles.count } do
      @user.notifications.create!(source: events(:logo_published), creator: @user)
    end
  end

  test "notifications are bundled within the aggregation period" do
    @user.notification_bundles.destroy_all

    notification_1 = assert_difference -> { @user.notification_bundles.pending.count }, 1 do
      @user.notifications.create!(source: events(:logo_published), creator: @user)
    end
    travel_to 3.hours.from_now

    notification_2 = assert_no_difference -> { @user.notification_bundles.count } do
      @user.notifications.create!(source: events(:layout_published), creator: @user)
    end
    travel_to 3.days.from_now

    notification_3 = assert_difference -> { @user.notification_bundles.pending.count }, 1 do
      @user.notifications.create!(source: events(:text_published), creator: @user)
    end

    assert_equal 2, @user.notification_bundles.count
    bundle_1, bundle_2 = @user.notification_bundles.all.to_a
    assert_includes bundle_1.notifications, notification_1
    assert_includes bundle_1.notifications, notification_2
    assert_includes bundle_2.notifications, notification_3
  end

  test "overlapping bundles are invalid" do
    bundle_1 = @user.notification_bundles.create!(
      starts_at: Time.current,
      ends_at: 4.hours.from_now,
      status: :pending
    )

    bundle_2 = @user.notification_bundles.build(
      starts_at: 2.hours.from_now,
      ends_at: 6.hours.from_now,
      status: :pending
    )
    assert_not bundle_2.valid?

    # Bundle with overlapping end time should be invalid
    bundle_3 = @user.notification_bundles.build(
      starts_at: 2.hours.ago,
      ends_at: 2.hours.from_now,
      status: :pending
    )
    assert_not bundle_3.valid?

    # Bundle completely within another bundle should be invalid
    bundle_4 = @user.notification_bundles.build(
      starts_at: 1.hour.from_now,
      ends_at: 3.hours.from_now,
      status: :pending
    )
    assert_not bundle_4.valid?

    # Non-overlapping bundle should be valid
    bundle_5 = @user.notification_bundles.build(
      starts_at: 5.hours.from_now,
      ends_at: 9.hours.from_now,
      status: :pending
    )
    assert bundle_5.valid?
  end

  test "overlapping bundles that are created relying on set_default_window are not created" do
    @user.notification_bundles.destroy_all

    bundle = @user.notification_bundles.create!(starts_at: Time.current)

    assert_raises ActiveRecord::RecordInvalid do
      @user.notification_bundles.create!(starts_at: bundle.starts_at - 1.second)
    end
  end

  test "deliver_all delivers due bundles" do
    @user.notification_bundles.destroy_all

    notification = @user.notifications.create!(source: events(:logo_published), creator: @user)

    bundle = @user.notification_bundles.pending.last

    assert bundle.pending?
    assert_includes bundle.notifications, notification

    bundle.update!(ends_at: 1.minute.ago)

    perform_enqueued_jobs only: Notification::Bundle::DeliverJob do
      Notification::Bundle.deliver_all
    end

    bundle.reload
    assert bundle.delivered?
  end

  test "deliver_all don't deliver bundles that are not due" do
    @user.notifications.create!(source: events(:logo_published), creator: @user)
    bundle = @user.notification_bundles.pending.last

    bundle.update!(ends_at: 1.minute.from_now)

    perform_enqueued_jobs only: Notification::Bundle::DeliverJob do
      Notification::Bundle.deliver_all
    end

    bundle.reload
    assert bundle.pending?
  end

  test "deliver sends email with time in user's time zone" do
    @user.settings.update!(timezone_name: "Madrid")

    freeze_time Time.utc(2025, 1, 15, 14, 30, 0) do
      @user.notifications.create!(source: events(:logo_published), creator: @user)
      bundle = @user.notification_bundles.pending.last
      bundle.deliver

      email = ActionMailer::Base.deliveries.last
      assert_not_nil email

      # Time in Madrid should be 15:30 (UTC+1 in winter)
      assert_match /notifications since 3pm/i, email.text_part&.body&.to_s
    end
  end

  test "out-of-order notification bundling should still work" do
    first_notification = @user.notifications.create!(source: events(:logo_published), creator: @user)
    second_notification = @user.notifications.create!(source: events(:layout_commented), creator: @user)
    @user.notification_bundles.destroy_all

    assert first_notification.updated_at <= second_notification.updated_at
    @user.bundle(second_notification)
    @user.bundle(first_notification)

    assert_equal 1, @user.notification_bundles.pending.count
    assert_equal 2, @user.notification_bundles.last.notifications.count
    assert_includes @user.notification_bundles.last.notifications, first_notification
    assert_includes @user.notification_bundles.last.notifications, second_notification
  end

  test "deliver does not send email for cancelled accounts" do
    @user.notifications.create!(source: events(:logo_published), creator: @user)
    bundle = @user.notification_bundles.pending.last

    @user.account.cancel(initiated_by: @user)

    assert_no_emails do
      deliver_enqueued_emails do
        bundle.deliver
      end
    end

    assert bundle.delivered?, "Bundle should be marked as delivered even if not sent"
  end
end
