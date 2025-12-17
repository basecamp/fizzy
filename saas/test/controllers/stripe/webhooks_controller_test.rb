require "test_helper"
require "ostruct"

class Stripe::WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = Account.create!(name: "Test")
    @subscription = @account.create_subscription! \
      plan_key: "monthly_v1",
      status: "incomplete",
      stripe_customer_id: "cus_test123"
  end

  test "invalid signature returns bad request" do
    Stripe::Webhook.stubs(:construct_event).raises(Stripe::SignatureVerificationError.new("invalid", "sig"))

    post stripe_webhooks_path
    assert_response :bad_request
  end

  test "checkout session completed activates subscription" do
    stripe_sub = OpenStruct.new(id: "sub_123", customer: "cus_test123", status: "active", cancel_at: nil, items: stub_items(1.month.from_now.to_i))

    event = stripe_event("checkout.session.completed",
      mode: "subscription",
      customer: "cus_test123",
      subscription: "sub_123",
      metadata: { "plan_key" => "monthly_v1" }
    )

    Stripe::Webhook.stubs(:construct_event).returns(event)
    Stripe::Subscription.stubs(:retrieve).returns(stripe_sub)
    Stripe::Invoice.stubs(:create_preview).returns(OpenStruct.new(amount_due: 1999))

    post stripe_webhooks_path

    assert_response :ok
    @subscription.reload
    assert_equal "sub_123", @subscription.stripe_subscription_id
    assert_equal "active", @subscription.status
  end

  test "subscription updated changes status and syncs next amount due" do
    @subscription.update!(stripe_subscription_id: "sub_123", status: "active")

    stripe_sub = OpenStruct.new(
      id: "sub_123",
      customer: "cus_test123",
      status: "past_due",
      cancel_at: nil,
      items: stub_items(1.month.from_now.to_i)
    )

    event = stripe_event("customer.subscription.updated", id: "sub_123")

    Stripe::Webhook.stubs(:construct_event).returns(event)
    Stripe::Subscription.stubs(:retrieve).returns(stripe_sub)
    Stripe::Invoice.stubs(:create_preview).returns(OpenStruct.new(amount_due: 1999))

    post stripe_webhooks_path

    assert_response :ok
    @subscription.reload
    assert_equal "past_due", @subscription.status
    assert_equal 1999, @subscription.next_amount_due_in_cents
  end

  test "subscription deleted cancels subscription" do
    @subscription.update!(stripe_subscription_id: "sub_123", status: "active")

    stripe_sub = OpenStruct.new(
      id: "sub_123",
      customer: "cus_test123",
      status: "canceled",
      cancel_at: nil,
      items: stub_items(1.month.from_now.to_i)
    )

    event = stripe_event("customer.subscription.deleted", id: "sub_123")

    Stripe::Webhook.stubs(:construct_event).returns(event)
    Stripe::Subscription.stubs(:retrieve).returns(stripe_sub)

    post stripe_webhooks_path

    assert_response :ok
    @subscription.reload
    assert_equal "canceled", @subscription.status
    assert_nil @subscription.stripe_subscription_id
    assert_nil @subscription.next_amount_due_in_cents
  end

  private
    def stripe_event(type, **attributes)
      OpenStruct.new(type: type, data: OpenStruct.new(object: OpenStruct.new(attributes)))
    end

    def stub_items(current_period_end)
      OpenStruct.new(data: [ OpenStruct.new(current_period_end: current_period_end) ])
    end
end
