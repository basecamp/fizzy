require "test_helper"

class Account::JoinCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "reset" do
    get account_join_code_path
    assert_response :success

    assert_changes -> { Current.account.join_code.reload.code } do
      delete account_join_code_path
      assert_redirected_to account_join_code_path
    end
  end

  test "update" do
    get edit_account_join_code_path
    assert_response :success

    put account_join_code_path, params: { account_join_code: { usage_limit: 5 } }
    assert_equal 5, Current.account.join_code.reload.usage_limit
    assert_redirected_to account_join_code_path
  end

  test "show as JSON" do
    get account_join_code_path, as: :json
    assert_response :success

    body = @response.parsed_body
    assert body["code"].present?
    assert body.key?("usage_count")
    assert body.key?("usage_limit")
    assert body.key?("url")
    assert body.key?("active")
  end

  test "update as JSON" do
    put account_join_code_path, params: { account_join_code: { usage_limit: 5 } }, as: :json

    assert_response :no_content
    assert_equal 5, Current.account.join_code.reload.usage_limit
  end

  test "update as JSON with invalid data" do
    huge_number = "99999999999999999999999999999999999"

    put account_join_code_path, params: { account_join_code: { usage_limit: huge_number } }, as: :json

    assert_response :unprocessable_entity
  end

  test "destroy as JSON" do
    assert_changes -> { Current.account.join_code.reload.code } do
      delete account_join_code_path, as: :json
    end

    assert_response :no_content
  end

  test "update requires admin" do
    logout_and_sign_in_as :david

    put account_join_code_path, params: { account_join_code: { usage_limit: 5 } }
    assert_response :forbidden
  end

  test "destroy requires admin" do
    logout_and_sign_in_as :david

    delete account_join_code_path
    assert_response :forbidden
  end

  test "update with extremely large usage_limit" do
    # A number larger than bigint max (2^63 - 1 = 9223372036854775807)
    huge_number = "99999999999999999999999999999999999"

    put account_join_code_path, params: { account_join_code: { usage_limit: huge_number } }

    assert_response :unprocessable_entity
    assert_select ".txt-negative", text: /cannot be larger than the population of the planet/
  end
end
