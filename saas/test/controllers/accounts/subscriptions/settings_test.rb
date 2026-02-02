require "test_helper"

class Account::Subscriptions::SettingsTest < ActionDispatch::IntegrationTest
  test "free users see current usage" do
    sign_in_as :mike

    accounts(:initech).update_column(:cards_count, 3)

    get account_settings_path(script_name: accounts(:initech).slug)

    assert_response :success
    assert_match /You’ve used.*3.*free cards out of 1,000/i, response.body
  end

  test "paid users see thank you message" do
    sign_in_as :kevin

    accounts(:"37s").subscription.update!(plan: Plan.paid, status: :active)

    get account_settings_path(script_name: accounts(:"37s").slug)

    assert_response :success
    assert_select "h3", text: "Thank you for buying Fizzy"
  end

  test "regular plan users see upgrade option" do
    sign_in_as :kevin

    accounts(:"37s").subscription.update!(plan: Plan.paid, status: :active)

    get account_settings_path(script_name: accounts(:"37s").slug)

    assert_response :success
    assert_select "button", text: /upgrade/i
    assert_select "button", text: /downgrade/i, count: 0
  end

  test "extra storage plan users see downgrade option" do
    sign_in_as :kevin

    accounts(:"37s").subscription.update!(plan: Plan.paid_with_extra_storage, status: :active)

    get account_settings_path(script_name: accounts(:"37s").slug)

    assert_response :success
    assert_select "button", text: /downgrade/i
  end

  test "comped accounts see no subscription panel" do
    sign_in_as :mike

    accounts(:initech).comp

    get account_settings_path(script_name: accounts(:initech).slug)

    assert_response :success
    assert_no_match /thank you for buying/i, response.body
    assert_no_match /free cards out of/i, response.body
    assert_no_match /upgrade/i, response.body
    assert_no_match /downgrade/i, response.body
  end
end
