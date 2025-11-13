require "test_helper"

class Sessions::MenusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = identities(:kevin)
  end

  test "show with no memberships" do
    sign_in_as @identity
    @identity.users.delete_all

    untenanted do
      get session_menu_url
    end

    assert_response :success, "Renders an empty menu"
  end

  test "show with exactly one membership" do
    sign_in_as @identity
    @identity.users.delete_all
    account = Account.create!(external_account_id: 9999991, name: "Test Account")
    @identity.users.create!(account: account, name: "Kevin")

    untenanted do
      get session_menu_url
    end

    assert_response :redirect
    assert_redirected_to root_url(script_name: "/9999991")
  end

  test "show with multiple memeberships" do
    sign_in_as @identity
    @identity.users.delete_all
    account1 = Account.create!(external_account_id: 9999992, name: "37signals")
    account2 = Account.create!(external_account_id: 9999993, name: "Acme")
    @identity.users.create!(account: account1, name: "Kevin")
    @identity.users.create!(account: account2, name: "Kevin")

    untenanted do
      get session_menu_url
    end

    assert_response :success
  end
end
