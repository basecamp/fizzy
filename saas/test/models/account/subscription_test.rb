require "test_helper"

class Account::SubscriptionTest < ActiveSupport::TestCase
  test "get the account plan" do
    subscription = Account::Subscription.new(plan_key: "free_v1")
    assert_equal Plan[:free_v1], subscription.plan
  end

  test "check if account is active" do
    subscription = Account::Subscription.new(status: "active")
    assert subscription.active?
  end

  test "check if account is paid" do
    assert Account::Subscription.new(plan_key: "monthly_v1", status: "active").paid?
    assert_not Account::Subscription.new(plan_key: "free_v1", status: "active").paid?
  end
end
