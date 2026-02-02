require "test_helper"
require "ostruct"

class Account::Subscriptions::DowngradesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    accounts(:"37s").subscription.update!(stripe_subscription_id: "sub_123", plan: Plan.paid_with_extra_storage)
  end

  test "downgrade redirects to stripe billing portal" do
    stripe_subscription = OpenStruct.new(items: OpenStruct.new(data: [ OpenStruct.new(id: "si_123") ]))
    portal_session = OpenStruct.new(url: "https://billing.stripe.com/session/abc123")

    Stripe::Subscription.stubs(:retrieve).with("sub_123").returns(stripe_subscription)
    Stripe::BillingPortal::Session.stubs(:create).returns(portal_session)

    post account_subscription_downgrade_path

    assert_redirected_to "https://billing.stripe.com/session/abc123"
  end

  test "downgrade requires admin" do
    logout_and_sign_in_as :david

    post account_subscription_downgrade_path
    assert_response :forbidden
  end

  test "downgrade requires downgradeable plan" do
    accounts(:"37s").subscription.update!(plan: Plan.paid)

    post account_subscription_downgrade_path
    assert_response :bad_request
  end
end
