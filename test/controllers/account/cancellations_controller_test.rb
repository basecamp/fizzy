require "test_helper"

class Account::CancellationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:"37s")
    @user = users(:jason)
    sign_in_as @user

    Account.multi_tenant = true

    if @account.respond_to?(:subscription)
      Account.any_instance.stubs(:subscription).returns(nil)
    end
  end

  teardown do
    Account.multi_tenant = false
  end

  test "an owner can cancel the account" do
    assert_difference -> { Account::Cancellation.count }, 1 do
      assert_enqueued_emails 1 do
        post account_cancellation_url
      end
    end

    assert_redirected_to session_menu_path
    assert_equal "Account deleted", flash[:notice]
    assert @account.reload.cancelled?
    assert_equal @user, @account.cancellation.initiated_by
  end

  test "non-owner cannot cancel the account" do
    logout_and_sign_in_as users(:david)

    assert_no_difference -> { Account::Cancellation.count } do
      post account_cancellation_url
    end

    assert_response :forbidden
  end

  test "cancelling an account while in single-tenant mode does nothing" do
    previous_multi_tenant_value = Account.multi_tenant
    Account.multi_tenant = false

    assert_no_difference -> { Account::Cancellation.count } do
      post account_cancellation_url
    end

    assert_not @account.reload.cancelled?
  ensure
    Account.multi_tenant = previous_multi_tenant_value
  end
end
