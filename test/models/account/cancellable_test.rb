require "test_helper"

class Account::CancellableTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:"37s")
    @user = users(:david)
  end

  test "cancel" do
    if @account.respond_to?(:subscription)
      subscription = mock("subscription")
      subscription.expects(:pause).once
      @account.stubs(:subscription).returns(subscription)
    end

    assert_difference -> { Account::Cancellation.count }, 1 do
      assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
        @account.cancel(initiated_by: @user)
      end
    end

    assert @account.cancelled?
    assert_equal @user, @account.cancellation.initiated_by
  end

  test "cancel when the account has a subscription" do
    subscription = mock("subscription")
    subscription.expects(:pause).once
    @account.stubs(:subscription).returns(subscription)

    @account.cancel(initiated_by: @user)
  end

  test "cancel does nothing if already cancelled" do
    @account.cancel(initiated_by: @user)

    assert_no_changes -> { @account.cancellation.reload.created_at } do
      @account.cancel(initiated_by: @user)
    end
  end

  test "cancel does nothing when in single-tenant mode" do
    Account.stubs(:accepting_signups?).returns(false)

    assert_no_difference -> { Account::Cancellation.count } do
      @account.cancel(initiated_by: @user)
    end

    assert_not @account.cancelled?
  end

  test "cancelled? returns true when cancellation exists" do
    assert_not @account.cancelled?

    @account.cancel(initiated_by: @user)

    assert @account.cancelled?
  end

  test "up_for_incineration finds old cancellations" do
    @account.cancel(initiated_by: @user)

    @account.cancellation.update!(created_at: 31.days.ago)
    assert_equal [ @account ], Account.up_for_incineration

    @account.cancellation.update!(created_at: 29.days.ago)
    assert Account.up_for_incineration.empty?
  end

  test "reactivate" do
    @account.cancel(initiated_by: @user)

    assert @account.cancelled?

    @account.reactivate
    @account.reload

    assert_not @account.cancelled?
    assert_nil @account.cancellation
  end

  test "reactivate when the account has a subscription" do
    @account.cancel(initiated_by: @user)

    subscription = mock("subscription")
    subscription.expects(:resume).once
    @account.stubs(:subscription).returns(subscription)

    @account.reactivate
  end

  test "reactivate does nothing if not cancelled" do
    assert_not @account.cancelled?

    assert_nothing_raised do
      @account.reactivate
    end

    assert_not @account.cancelled?
  end
end
