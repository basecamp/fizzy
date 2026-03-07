require "test_helper"

class Account::EntropiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update" do
    put account_entropy_path, params: { entropy: { auto_postpone_period: 1.day } }

    assert_equal 1.day, entropies("37s_account").auto_postpone_period

    assert_redirected_to account_settings_path
  end

  test "update requires admin" do
    logout_and_sign_in_as :david

    put account_entropy_path, params: { entropy: { auto_postpone_period: 1.day } }
    assert_response :forbidden
  end

  test "update as JSON" do
    put account_entropy_path, params: { entropy: { auto_postpone_period: 7.days } }, as: :json

    assert_response :success
    assert_equal 7.days, entropies("37s_account").reload.auto_postpone_period
    assert_equal 7.days, @response.parsed_body["auto_postpone_period"]
  end

  test "update as JSON requires admin" do
    logout_and_sign_in_as :david

    put account_entropy_path, params: { entropy: { auto_postpone_period: 1.day } }, as: :json
    assert_response :forbidden
  end
end
