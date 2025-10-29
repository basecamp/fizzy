require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    identity = Identity.create!(email_address: "new.user@example.com")
    identity.memberships.create(tenant: ApplicationRecord.current_tenant, join_code: Account::JoinCode.sole.code)
    sign_in_as identity

    get new_user_path
    assert_response :ok
  end

  test "new with invalid params" do
    identity = Identity.create!(email_address: "new.user@example.com")
    membership = identity.memberships.create(tenant: ApplicationRecord.current_tenant, join_code: "PHONY")
    sign_in_as identity

    get new_user_path
    assert_redirected_to unlink_membership_url(script_name: nil, membership_id: membership.signed_id(purpose: :unlinking))
  end

  test "create" do
    identity = Identity.create!(email_address: "newart.userbaum@example.com")
    identity.memberships.create(tenant: ApplicationRecord.current_tenant, join_code: Account::JoinCode.sole.code)
    sign_in_as identity

    assert_difference -> { User.count }, +1 do
      post users_path, params: { user: { name: "Newart Userbaum" } }
      assert_redirected_to root_path
    end
  end

  test "show" do
    sign_in_as :kevin

    get user_path(users(:david))
    assert_in_body users(:david).name
  end

  test "update oneself" do
    sign_in_as :kevin

    get edit_user_path(users(:kevin))
    assert_response :ok

    put user_path(users(:kevin)), params: { user: { name: "New Kevin" } }
    assert_redirected_to user_path(users(:kevin))
    assert_equal "New Kevin", users(:kevin).reload.name
  end

  test "update other as admin" do
    sign_in_as :kevin

    get edit_user_path(users(:david))
    assert_response :ok

    put user_path(users(:david)), params: { user: { name: "New David" } }
    assert_redirected_to user_path(users(:david))
    assert_equal "New David", users(:david).reload.name
  end

  test "destroy" do
    sign_in_as :kevin

    assert_difference -> { User.active.count }, -1 do
      delete user_path(users(:david))
    end

    assert_redirected_to users_path
    assert_nil User.active.find_by(id: users(:david).id)
  end

  test "non-admins cannot perform actions" do
    sign_in_as :jz

    put user_path(users(:david)), params: { user: { role: "admin" } }
    assert_response :forbidden

    delete user_path(users(:david))
    assert_response :forbidden
  end
end
