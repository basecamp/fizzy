require "test_helper"

class Account::EntropiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update" do
    put account_entropy_path, params: { entropy: { auto_postpone_period_in_days: 7 } }

    assert_equal 7.days, entropies("37s_account").auto_postpone_period

    assert_redirected_to account_settings_path
  end

  test "update as JSON" do
    put account_entropy_path, params: { entropy: { auto_postpone_period_in_days: 7 } }, as: :json

    assert_response :success
    assert_equal 7.days, entropies("37s_account").reload.auto_postpone_period
    assert_equal 7, @response.parsed_body["auto_postpone_period_in_days"]
  end

  test "update requires admin" do
    logout_and_sign_in_as :david

    put account_entropy_path, params: { entropy: { auto_postpone_period_in_days: 7 } }
    assert_response :forbidden
  end

  test "update rejects invalid auto_postpone_period" do
    original_period = entropies("37s_account").auto_postpone_period

    put account_entropy_path, params: { entropy: { auto_postpone_period_in_days: 1 } }

    assert_response :unprocessable_entity
    assert_equal original_period, entropies("37s_account").reload.auto_postpone_period
  end

  test "update as JSON rejects invalid auto_postpone_period" do
    original_period = entropies("37s_account").auto_postpone_period

    put account_entropy_path, params: { entropy: { auto_postpone_period_in_days: 1 } }, as: :json

    assert_response :unprocessable_entity
    assert_equal original_period, entropies("37s_account").reload.auto_postpone_period
  end

  test "update as JSON requires admin" do
    logout_and_sign_in_as :david

    put account_entropy_path, params: { entropy: { auto_postpone_period_in_days: 7 } }, as: :json
    assert_response :forbidden
  end
end
