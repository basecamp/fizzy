require "test_helper"

class Admin::BillingWaiversControllerTest < ActionDispatch::IntegrationTest
  test "staff can comp an account" do
    sign_in_as :david
    account = accounts(:"37s")

    assert_not account.comped?

    untenanted do
      post saas.admin_account_billing_waiver_path(account.external_account_id)
      assert_redirected_to saas.edit_admin_account_path(account.external_account_id)
    end

    assert account.reload.comped?
  end

  test "staff can uncomp an account" do
    sign_in_as :david
    account = accounts(:"37s")
    account.comp

    assert account.comped?

    untenanted do
      delete saas.admin_account_billing_waiver_path(account.external_account_id)
      assert_redirected_to saas.edit_admin_account_path(account.external_account_id)
    end

    assert_not account.reload.comped?
  end
end
