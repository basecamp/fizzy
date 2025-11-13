require "test_helper"

class Account::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get account_settings_path
    assert_response :success
  end

  test "update" do
    put account_settings_path, params: { account: { name: "New Account Name" } }
    assert_equal "New Account Name", Current.account.reload.name
    assert_redirected_to account_settings_path
  end

  test "update requires admin" do
    logout_and_sign_in_as :david

    put account_settings_path, params: { account: { name: "New Account Name" } }
    assert_response :forbidden
  end
end
