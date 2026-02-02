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

  test "pause pauses Stripe subscription with void behavior" do
    subscription = Account::Subscription.new(stripe_subscription_id: "sub_123")

    Stripe::Subscription.expects(:update).with(
      "sub_123",
      pause_collection: { behavior: "void" }
    ).returns(true)

    subscription.pause
  end

  test "pause does nothing when no stripe_subscription_id" do
    subscription = Account::Subscription.new(stripe_subscription_id: nil)

    Stripe::Subscription.expects(:update).never

    subscription.pause
  end

  test "pause raises on Stripe errors" do
    subscription = Account::Subscription.new(stripe_subscription_id: "sub_123")

    Stripe::Subscription.stubs(:update).raises(
      Stripe::APIConnectionError.new("Network error")
    )

    assert_raises Stripe::APIConnectionError do
      subscription.pause
    end
  end

  test "resume resumes Stripe subscription" do
    subscription = Account::Subscription.new(stripe_subscription_id: "sub_123")

    Stripe::Subscription.expects(:update).with(
      "sub_123",
      pause_collection: ""
    ).returns(true)

    subscription.resume
  end

  test "resume does nothing when no stripe_subscription_id" do
    subscription = Account::Subscription.new(stripe_subscription_id: nil)

    Stripe::Subscription.expects(:update).never

    subscription.resume
  end

  test "resume raises on Stripe errors" do
    subscription = Account::Subscription.new(stripe_subscription_id: "sub_123")

    Stripe::Subscription.stubs(:update).raises(
      Stripe::AuthenticationError.new("Invalid API key")
    )

    assert_raises Stripe::AuthenticationError do
      subscription.resume
    end
  end

  test "cancel cancels Stripe subscription" do
    subscription = Account::Subscription.new(stripe_subscription_id: "sub_123")

    Stripe::Subscription.expects(:cancel).with("sub_123").returns(true)

    subscription.cancel
  end

  test "cancel does nothing when no stripe_subscription_id" do
    subscription = Account::Subscription.new(stripe_subscription_id: nil)

    Stripe::Subscription.expects(:cancel).never

    subscription.cancel
  end

  test "cancel treats 404 as success" do
    subscription = Account::Subscription.new(stripe_subscription_id: "sub_deleted")

    Stripe::Subscription.stubs(:cancel).raises(
      Stripe::InvalidRequestError.new("No such subscription", {})
    )

    assert_nothing_raised do
      subscription.cancel
    end
  end

  test "cancel raises on other Stripe errors" do
    subscription = Account::Subscription.new(stripe_subscription_id: "sub_123")

    Stripe::Subscription.stubs(:cancel).raises(
      Stripe::RateLimitError.new("Rate limit exceeded")
    )

    assert_raises Stripe::RateLimitError do
      subscription.cancel
    end
  end

  test "sync_customer_email_to_stripe updates Stripe customer with owner email" do
    account = accounts(:"37s")
    owner = account.users.find_by(role: :owner) || account.users.first.tap { |u| u.update!(role: :owner) }
    subscription = account.create_subscription!(
      stripe_customer_id: "cus_test",
      plan_key: "monthly_v1",
      status: "active"
    )

    Stripe::Customer.expects(:update).with("cus_test", email: owner.identity.email_address).once

    subscription.sync_customer_email_to_stripe
  end

  test "sync_customer_email_to_stripe does nothing without stripe_customer_id" do
    account = accounts(:"37s")
    subscription = account.build_subscription(
      stripe_customer_id: nil,
      plan_key: "free_v1",
      status: "active"
    )

    Stripe::Customer.expects(:update).never

    subscription.sync_customer_email_to_stripe
  end

  test "sync_customer_email_to_stripe does nothing without owner" do
    account = accounts(:"37s")
    account.users.update_all(role: :member)
    subscription = account.create_subscription!(
      stripe_customer_id: "cus_test",
      plan_key: "monthly_v1",
      status: "active"
    )

    Stripe::Customer.expects(:update).never

    subscription.sync_customer_email_to_stripe
  end

  test "sync_customer_email_to_stripe does nothing when owner has no identity" do
    account = accounts(:"37s")
    owner = account.users.find_by(role: :owner) || account.users.first.tap { |u| u.update!(role: :owner) }
    owner.update_column(:identity_id, nil)
    subscription = account.create_subscription!(
      stripe_customer_id: "cus_test",
      plan_key: "monthly_v1",
      status: "active"
    )

    Stripe::Customer.expects(:update).never

    subscription.sync_customer_email_to_stripe
  end

  test "sync_customer_email_to_stripe treats deleted customer as success" do
    account = accounts(:"37s")
    account.users.find_by(role: :owner) || account.users.first.tap { |u| u.update!(role: :owner) }
    subscription = account.create_subscription!(
      stripe_customer_id: "cus_deleted",
      plan_key: "monthly_v1",
      status: "active"
    )

    Stripe::Customer.stubs(:update).raises(
      Stripe::InvalidRequestError.new("No such customer", {})
    )

    assert_nothing_raised do
      subscription.sync_customer_email_to_stripe
    end
  end
end
