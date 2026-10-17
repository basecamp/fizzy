require "test_helper"

class Users::RolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update" do
    assert_not users(:david).admin?

    put user_role_path(users(:david)), params: { user: { role: "admin" } }

    assert_redirected_to account_settings_path
    assert users(:david).reload.admin?
  end

  test "update is forbidden with single sign-on" do
    current_session.update!(single_sign_on_authenticated_at: Time.current, single_sign_on_issuer: SINGLE_SIGN_ON_ISSUER)

    with_single_sign_on do
      put user_role_path(users(:david)), params: { user: { role: "admin" } }
    end

    assert_response :forbidden
    assert_not users(:david).reload.admin?
  end

  test "update as JSON" do
    put user_role_path(users(:david)), params: { user: { role: "admin" } }, as: :json

    assert_response :no_content
    assert users(:david).reload.admin?
  end

  test "can't promote to special roles" do
    assert_no_changes -> { users(:david).reload.role } do
      put user_role_path(users(:david)), params: { user: { role: "system" } }
    end

    assert_no_changes -> { users(:david).reload.role } do
      put user_role_path(users(:david)), params: { user: { role: "owner" } }
    end
  end

  test "admin cannot demote the owner" do
    assert users(:jason).owner?

    assert_no_changes -> { users(:jason).reload.role } do
      put user_role_path(users(:jason)), params: { user: { role: "admin" } }
    end

    assert_response :forbidden
  end

  test "admin cannot change owner role to member" do
    assert users(:jason).owner?

    assert_no_changes -> { users(:jason).reload.role } do
      put user_role_path(users(:jason)), params: { user: { role: "member" } }
    end

    assert_response :forbidden
  end
end
