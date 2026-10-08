require "test_helper"

class Account::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get account_settings_path
    assert_response :success
    assert_select "h2", text: "SSO group", count: 0
    assert_select "a[href='#{account_join_code_path}']", text: /Invite people/
  end

  test "show the group field to members of the admin group" do
    current_session.update!(single_sign_on_authenticated_at: Time.current, single_sign_on_issuer: SINGLE_SIGN_ON_ISSUER, single_sign_on_groups: [ "/fizzy/admin" ])

    with_single_sign_on admin_group: "/fizzy/admin" do
      get account_settings_path
    end

    assert_select "h2", text: "SSO group"
    assert_select "input[name='account[single_sign_on_group]'][type=text]:not([readonly])"
    assert_select "a[href='#{account_join_code_path}']", count: 0
    assert_select "input[name='user[role]'][type=checkbox]"
    assert_select "input[name='user[role]'][type=checkbox]:not([disabled])", count: 0
  end

  test "show account admins a read-only group field" do
    current_session.update!(single_sign_on_authenticated_at: Time.current, single_sign_on_issuer: SINGLE_SIGN_ON_ISSUER)

    with_single_sign_on do
      get account_settings_path
    end

    assert_select "input[name='account[single_sign_on_group]'][readonly]"
    assert_select "form[action$='/account/single_sign_on'] button", count: 0
  end

  test "show as JSON includes the single sign-on group" do
    accounts("37s").update!(single_sign_on_group: "/engineering/fizzy")

    get account_settings_path, as: :json

    assert_equal "/engineering/fizzy", @response.parsed_body["single_sign_on_group"]
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
