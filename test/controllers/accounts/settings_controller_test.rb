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

  test "update as JSON" do
    put account_settings_path, params: { account: { name: "New Account Name" } }, as: :json

    assert_response :no_content
    assert_equal "New Account Name", Current.account.reload.name
  end

  test "update requires admin" do
    logout_and_sign_in_as :david

    put account_settings_path, params: { account: { name: "New Account Name" } }
    assert_response :forbidden
  end

  test "show as JSON" do
    get account_settings_path, as: :json

    assert_response :success
    assert_equal Current.account.name, @response.parsed_body["name"]
    assert_equal Current.account.cards_count, @response.parsed_body["cards_count"]
    assert_equal Current.account.entropy.auto_postpone_period_in_days, @response.parsed_body["auto_postpone_period_in_days"]
  end
end
