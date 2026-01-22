require "test_helper"

class Notification::PushableTest < ActiveSupport::TestCase
  setup do
    @user = users(:david)
    @notification = @user.notifications.create!(
      source: events(:logo_published),
      creator: users(:jason)
    )
  end

  test "push_later enqueues Notification::PushJob" do
    assert_enqueued_with(job: Notification::PushJob, args: [ @notification ]) do
      @notification.push_later
    end
  end

  test "push calls process on all registered targets" do
    target_class = mock("push_target_class")
    target_class.expects(:process).with(@notification)

    original_targets = Notification.push_targets
    Notification.push_targets = [ target_class ]

    @notification.push
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

  test "push processes targets for normal notifications" do
    target_class = mock("push_target_class")
    target_class.expects(:process).with(@notification)

    original_targets = Notification.push_targets
    Notification.push_targets = [ target_class ]

    @notification.push
  ensure
    Notification.push_targets = original_targets
  end

  test "push skips targets when creator is system user" do
    @notification.update!(creator: users(:system))

    target_class = mock("push_target_class")
    target_class.expects(:process).never

    original_targets = Notification.push_targets
    Notification.push_targets = [ target_class ]

    @notification.push
  ensure
    Notification.push_targets = original_targets
  end

  test "push skips targets for cancelled accounts" do
    @user.account.cancel(initiated_by: @user)

    target_class = mock("push_target_class")
    target_class.expects(:process).never

    original_targets = Notification.push_targets
    Notification.push_targets = [ target_class ]

    @notification.push
  ensure
    Notification.push_targets = original_targets
  end
end
