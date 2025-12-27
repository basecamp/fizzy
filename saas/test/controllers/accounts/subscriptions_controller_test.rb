require "test_helper"
require "ostruct"

class Account::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get account_subscription_path
    assert_response :success
  end

  test "show with session_id retrieves stripe session" do
    Stripe::Checkout::Session.stubs(:retrieve).with("sess_123").returns(OpenStruct.new(id: "sess_123"))

    get account_subscription_path(session_id: "sess_123")
    assert_response :success
  end

  test "show requires admin" do
    logout_and_sign_in_as :david

    get account_subscription_path
    assert_response :forbidden
  end

  test "create redirects to stripe checkout" do
    customer = OpenStruct.new(id: "cus_test_37signals")
    session = OpenStruct.new(url: "https://checkout.stripe.com/session123")

    Stripe::Customer.stubs(:retrieve).returns(customer)
    Stripe::Checkout::Session.stubs(:create).returns(session)

    post account_subscription_path

    assert_redirected_to "https://checkout.stripe.com/session123"
  end

  test "create requires admin" do
    logout_and_sign_in_as :david

    post account_subscription_path
    assert_response :forbidden
  end

  test "create with custom plan_key redirects to stripe checkout" do
    customer = OpenStruct.new(id: "cus_test_37signals")
    session = OpenStruct.new(url: "https://checkout.stripe.com/session123")

    Stripe::Customer.stubs(:retrieve).returns(customer)
    Stripe::Checkout::Session.stubs(:create).with do |params|
      params[:metadata][:plan_key] == :monthly_extra_storage_v1
    end.returns(session)

    post account_subscription_path(plan_key: :monthly_extra_storage_v1)

    assert_redirected_to "https://checkout.stripe.com/session123"
  end
end
