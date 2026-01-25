require "test_helper"

class Account::BillingTest < ActiveSupport::TestCase
  test "plan reflects active subscription" do
    account = accounts(:initech)

    # No subscription
    assert_equal Plan.free, account.plan

    # Subscription but it is not active
    account.create_subscription!(plan_key: "monthly_v1", status: "canceled", stripe_customer_id: "cus_test")
    assert_equal Plan.free, account.plan

    # Active subscription exists
    account.subscription.update!(status: "active")
    assert_equal Plan.paid, account.plan
  end

  test "comped account" do
    account = accounts(:"37s")

    assert_not account.comped?

    account.comp
    assert account.comped?

    # Calling comp again does not create duplicate
    account.comp
    assert_equal 1, Account::BillingWaiver.where(account: account).count
  end

  test "cancel callback pauses subscription" do
    account = accounts(:"37s")
    user = users(:david)

    subscription = mock("subscription")
    subscription.expects(:pause).once
    account.stubs(:subscription).returns(subscription)

    account.cancel(initiated_by: user)
  end

  test "reactivate callback resumes subscription" do
    account = accounts(:"37s")
    user = users(:david)

    # First cancel with a subscription mock
    subscription_for_cancel = mock("subscription")
    subscription_for_cancel.expects(:pause).once
    account.stubs(:subscription).returns(subscription_for_cancel)

    account.cancel(initiated_by: user)

    # Now stub for reactivation
    subscription_for_reactivate = mock("subscription")
    subscription_for_reactivate.expects(:resume).once
    account.stubs(:subscription).returns(subscription_for_reactivate)

    account.reactivate
  end

  test "incinerate callback cancels subscription before destroying account" do
    account = accounts(:"37s")

    subscription = mock("subscription")
    subscription.expects(:cancel).once
    account.stubs(:subscription).returns(subscription)

    account.incinerate
  end

  test "owner_email_changed enqueues sync job when subscription exists" do
    account = accounts(:"37s")
    account.create_subscription!(
      stripe_customer_id: "cus_test",
      plan_key: "monthly_v1",
      status: "active"
    )

    assert_enqueued_with(job: Account::SyncStripeCustomerEmailJob, args: [ account.subscription ]) do
      account.owner_email_changed
    end
  end

  test "owner_email_changed does nothing without subscription" do
    account = accounts(:initech)
    account.subscription&.destroy

    assert_no_enqueued_jobs do
      account.owner_email_changed
    end
  end
end
