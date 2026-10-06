require "test_helper"

class Account::SingleSignOnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    enable_single_sign_on admin_group: "/fizzy/admin", account_admin_subgroup: "admin"
    sign_in_with_single_sign_on_as :kevin, groups: [ "/fizzy/admin" ]
  end

  teardown do
    disable_single_sign_on
  end

  test "a member of the admin group sets a group that they are not in" do
    patch account_single_sign_on_path, params: { account: { single_sign_on_group: " /sales " } }

    assert_redirected_to account_settings_path
    assert_equal "Account updated", flash[:notice]
    assert_equal "/sales", accounts("37s").reload.single_sign_on_group
  end

  test "set a group as JSON" do
    patch account_single_sign_on_path, params: { account: { single_sign_on_group: "/sales" } }, as: :json

    assert_response :success
    assert_equal "/sales", @response.parsed_body["single_sign_on_group"]
  end

  test "set a group that is not a full path" do
    patch account_single_sign_on_path, params: { account: { single_sign_on_group: "sales" } }

    assert_redirected_to account_settings_path
    assert_equal "Enter the full group path, such as /engineering/fizzy", flash[:alert]
    assert_nil accounts("37s").reload.single_sign_on_group
  end

  test "set a group that is not a full path as JSON" do
    patch account_single_sign_on_path, params: { account: { single_sign_on_group: "sales" } }, as: :json

    assert_response :unprocessable_entity
    assert_equal "Enter the full group path, such as /engineering/fizzy", @response.parsed_body["error"]
  end

  test "remove the group" do
    accounts("37s").update!(single_sign_on_group: "/sales")

    patch account_single_sign_on_path, params: { account: { single_sign_on_group: "" } }

    assert_redirected_to account_settings_path
    assert_nil accounts("37s").reload.single_sign_on_group
  end

  test "an account admin outside the admin group cannot change the group" do
    accounts("37s").update!(single_sign_on_group: "/engineering")
    sign_in_with_single_sign_on_as :kevin, groups: [ "/engineering/admin" ]
    assert users(:kevin).reload.admin?

    patch account_single_sign_on_path, params: { account: { single_sign_on_group: "/sales" } }

    assert_response :forbidden
    assert_equal "/engineering", accounts("37s").reload.single_sign_on_group
  end

  test "update is not found when single sign-on is not configured" do
    disable_single_sign_on

    patch account_single_sign_on_path, params: { account: { single_sign_on_group: "/sales" } }

    assert_response :not_found
  end
end
