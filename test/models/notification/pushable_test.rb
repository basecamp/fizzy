require "test_helper"

class Notification::PushableTest < ActiveSupport::TestCase
  setup do
    @user = users(:david)
    @notification = @user.notifications.create!(
      source: events(:logo_published),
      creator: users(:jason)
    )
  end

  test "push_later calls push_later on all registered targets" do
    target = mock("push_target")
    target.expects(:push_later).with(@notification)

    original_targets = Notification.push_targets
    Notification.push_targets = [ target ]

    @notification.push_later
  ensure
    Notification.push_targets = original_targets
  end

  test "push_later is called after notification is created" do
    Notification.any_instance.expects(:push_later)

    @user.notifications.create!(
      source: events(:logo_published),
      creator: users(:jason)
    )
  end

  test "register_push_target accepts symbols" do
    original_targets = Notification.push_targets.dup

    Notification.register_push_target(:web)

    assert_includes Notification.push_targets, Notification::PushTarget::Web
  ensure
    Notification.push_targets = original_targets
  end

  test "pushable? returns true for normal notifications" do
    assert @notification.pushable?
  end

  test "pushable? returns false when creator is system user" do
    @notification.update!(creator: users(:system))

    assert_not @notification.pushable?
  end

  test "pushable? returns false for cancelled accounts" do
    @user.account.cancel(initiated_by: @user)

    assert_not @notification.pushable?
  end
end
