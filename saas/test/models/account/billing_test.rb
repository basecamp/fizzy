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
end
