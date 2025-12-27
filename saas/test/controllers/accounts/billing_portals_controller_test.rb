require "test_helper"
require "ostruct"

class Account::BillingPortalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "redirects to stripe billing portal" do
    Current.account.subscription.update!(stripe_customer_id: "cus_test123")

    session = OpenStruct.new(url: "https://billing.stripe.com/session123")
    Stripe::BillingPortal::Session.expects(:create)
      .with(customer: "cus_test123", return_url: account_settings_url)
      .returns(session)

    get account_billing_portal_path

    assert_redirected_to "https://billing.stripe.com/session123"
  end

  test "requires admin" do
    logout_and_sign_in_as :david

    get account_billing_portal_path

    assert_response :forbidden
  end
end
