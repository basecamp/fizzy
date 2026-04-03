require "test_helper"

class User::SettingsTest < ActiveSupport::TestCase
  setup do
    @user = users(:david)
    @settings = @user.settings
  end

  test "changing the bundle email frequency to never will cancel pending bundles" do
    @settings.update!(bundle_email_frequency: :every_few_hours)
    bundle = @user.notification_bundles.create!
    @settings.update!(bundle_email_frequency: :never)
    assert_nil Notification::Bundle.find_by(id: bundle.id)
  end

  test "changing the bundle email frequency will deliver pending bundles" do
    bundle = @user.notification_bundles.create!
    assert bundle.pending?

    freeze_time Time.current do
      perform_enqueued_jobs only: Notification::Bundle::DeliverJob do
        @settings.update!(bundle_email_frequency: :daily)
      end

      assert bundle.reload.delivered?
      assert_equal Time.current, bundle.ends_at
    end
  end

  test "changing other settings will not affect pending bundles" do
    bundle = @user.notification_bundles.create!

    perform_enqueued_jobs only: Notification::Bundle::DeliverJob do
      @settings.update!(updated_at: 1.hour.from_now)
    end

    assert bundle.reload.pending?
  end

  test "bundling_emails?" do
    @settings.update!(bundle_email_frequency: :never)
    assert_not @user.settings.bundling_emails?

    @settings.update!(bundle_email_frequency: :every_few_hours)
    assert @user.settings.bundling_emails?

    @user.update!(role: :system)
    assert_not @user.settings.bundling_emails?, "System users should not receive bundled emails"

    @user.update!(role: :member, active: false)
    assert_not @user.settings.bundling_emails?, "Inactive users should not receive bundled emails"

    @user.update!(active: true)
    @user.update_column(:verified_at, nil)
    assert_not @user.settings.bundling_emails?, "Unverified users should not receive bundled emails"
  end

  test "push_notification_enabled_for? with only_mentions" do
    @settings.update!(push_notification_level: :only_mentions)

    assert @settings.push_notification_enabled_for?(notifications(:logo_mentioned_david))
    assert_not @settings.push_notification_enabled_for?(notifications(:logo_assignment_kevin))
    assert_not @settings.push_notification_enabled_for?(notifications(:layout_commented_kevin))
  end

  test "push_notification_enabled_for? with comments_and_mentions" do
    @settings.update!(push_notification_level: :comments_and_mentions)

    assert @settings.push_notification_enabled_for?(notifications(:logo_mentioned_david))
    assert @settings.push_notification_enabled_for?(notifications(:layout_commented_kevin))
    assert_not @settings.push_notification_enabled_for?(notifications(:logo_assignment_kevin))
  end

  test "push_notification_enabled_for? with all_activity" do
    @settings.update!(push_notification_level: :all_activity)

    assert @settings.push_notification_enabled_for?(notifications(:logo_mentioned_david))
    assert @settings.push_notification_enabled_for?(notifications(:layout_commented_kevin))
    assert @settings.push_notification_enabled_for?(notifications(:logo_assignment_kevin))
  end
end
