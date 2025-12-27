require "test_helper"

class Admin::OverriddenLimitsControllerTest < ActionDispatch::IntegrationTest
  test "staff can reset overridden limits" do
    sign_in_as :david
    account = accounts(:"37s")

    # First set an override
    account.override_limits(card_count: 500)
    assert_equal 500, account.reload.billed_cards_count

    # Then reset it
    untenanted do
      delete saas.admin_account_overridden_limits_path(account.external_account_id)
      assert_redirected_to saas.edit_admin_account_path(account.external_account_id)
    end

    # Verify override was removed
    assert_nil account.reload.overridden_limits
    assert_equal account.cards_count, account.billed_cards_count
  end
end
