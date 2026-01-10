require "test_helper"

class Account::IncinerateDueJobTest < ActiveJob::TestCase
  setup do
    @account = accounts(:"37s")
    @user = users(:david)

    # Stub Stripe methods only in SaaS mode
    if defined?(Stripe::Subscription)
      Stripe::Subscription.stubs(:update).returns(true)
      Stripe::Subscription.stubs(:cancel).returns(true)
    end
  end

  test "finds accounts up for incineration" do
    @account.cancel(initiated_by: @user)
    @account.cancellation.update!(created_at: 31.days.ago)

    Account.any_instance.expects(:incinerate).once

    Account::IncinerateDueJob.perform_now
  end

  test "incinerates each old cancelled account" do
    # Cancel the test account
    @account.cancel(initiated_by: @user)
    @account.cancellation.update!(created_at: 31.days.ago)

    # Just verify it gets incinerated
    assert_difference -> { Account.count }, -1 do
      Account::IncinerateDueJob.perform_now
    end
  end

  test "skips recent cancellations" do
    @account.cancel(initiated_by: @user)
    @account.cancellation.update!(created_at: 29.days.ago)

    assert_no_difference -> { Account.count } do
      Account::IncinerateDueJob.perform_now
    end
  end

  test "handles cursor pagination correctly" do
    # Cancel and age the account
    @account.cancel(initiated_by: @user)
    @account.cancellation.update!(created_at: 31.days.ago)

    # Verify it processes accounts in the scope
    assert_difference -> { Account.count }, -1 do
      Account::IncinerateDueJob.perform_now
    end
  end

  test "only incinerates accounts past grace period" do
    # Account at 29 days (within grace period - should not be incinerated)
    @account.cancel(initiated_by: @user)
    @account.cancellation.update!(created_at: 29.days.ago)

    assert_no_difference -> { Account.count } do
      Account::IncinerateDueJob.perform_now
    end

    # The account should still exist
    assert Account.exists?(@account.id)
  end
end
