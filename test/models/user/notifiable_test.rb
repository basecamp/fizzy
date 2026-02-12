require "test_helper"

class User::NotifiableTest < ActiveSupport::TestCase
  setup do
    @user = users(:david)
    @user.notifications.destroy_all
    @user.settings.bundle_email_every_few_hours!
  end

  test "bundle method creates new bundle for first notification" do
    notification = assert_difference -> { @user.notification_bundles.count }, 1 do
      @user.notifications.create!(source: events(:logo_published), creator: @user)
    end

    bundle = @user.notification_bundles.last
    assert_equal notification.updated_at, bundle.starts_at
    assert bundle.pending?
  end

  test "bundle method finds existing bundle within aggregation period" do
    @user.notifications.create!(source: events(:logo_published), creator: @user)

    assert_no_difference -> { @user.notification_bundles.count } do
      @user.notifications.create!(source: events(:layout_published), creator: @user)
    end
  end
end
