require "test_helper"

class Account::CancellableTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:"37s")
    @user = users(:david)
  end

  test "cancel" do
    assert_difference -> { Account::Cancellation.count }, 1 do
      assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
        @account.cancel(initiated_by: @user)
      end
    end

    assert @account.cancelled?
    assert_equal @user, @account.cancellation.initiated_by
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

  test "reactivate" do
    @account.cancel(initiated_by: @user)

    assert @account.cancelled?

    @account.reactivate
    @account.reload

    assert_not @account.cancelled?
    assert_nil @account.cancellation
  end

  test "reactivate does nothing if not cancelled" do
    assert_not @account.cancelled?

    assert_nothing_raised do
      @account.reactivate
    end

    assert_not @account.cancelled?
  end

  test "active scope excludes cancelled accounts" do
    account2 = accounts(:initech)

    initial_active_count = Account.active.count

    @account.cancel(initiated_by: @user)

    assert_equal initial_active_count - 1, Account.active.count
    assert_not_includes Account.active, @account
    assert_includes Account.active, account2
  end
end
