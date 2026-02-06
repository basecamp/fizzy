require "test_helper"

class Admin::AccountsControllerTest < ActionDispatch::IntegrationTest
  test "staff can access index" do
    sign_in_as :david

    untenanted do
      get saas.admin_accounts_path
    end

    assert_response :success
  end

  test "search account" do
    sign_in_as :david

    untenanted do
      post saas.admin_account_search_path, params: { q: accounts(:"37s").external_account_id }
      assert_redirected_to saas.edit_admin_account_path(accounts(:"37s").external_account_id)
    end
  end

  test "staff can edit account" do
    sign_in_as :david

    untenanted do
      get saas.edit_admin_account_path(accounts(:"37s").external_account_id)
    end

    assert_response :success
  end

  test "staff can override card count" do
    sign_in_as :david

    untenanted do
      patch saas.admin_account_path(accounts(:"37s").external_account_id), params: { account: { card_count: 500 } }
      assert_redirected_to saas.edit_admin_account_path(accounts(:"37s").external_account_id)
    end

    assert_equal 500, accounts(:"37s").reload.billed_cards_count
  end

  test "non-staff cannot access accounts" do
    sign_in_as :jz

    untenanted do
      patch saas.admin_account_path(accounts(:"37s").external_account_id), params: { account: { cards_count: 9999 } }
    end

    assert_response :forbidden
    assert_not_equal 9999, accounts(:"37s").reload.cards_count
  end
end
