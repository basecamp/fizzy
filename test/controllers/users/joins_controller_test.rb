require "test_helper"

class Users::JoinsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    identity = Identity.create!(email_address: "new.user@example.com")
    identity.memberships.create(tenant: ApplicationRecord.current_tenant, join_code: Account::JoinCode.sole.code)
    sign_in_as identity

    get new_users_join_path
    assert_response :ok
  end

  test "new with invalid params" do
    identity = Identity.create!(email_address: "new.user@example.com")
    membership = identity.memberships.create(tenant: ApplicationRecord.current_tenant, join_code: "PHONY")
    sign_in_as identity

    get new_users_join_path
    assert_redirected_to unlink_membership_url(script_name: nil, membership_id: membership.signed_id(purpose: :unlinking))
  end

  test "create" do
    identity = Identity.create!(email_address: "newart.userbaum@example.com")
    identity.memberships.create(tenant: ApplicationRecord.current_tenant, join_code: Account::JoinCode.sole.code)
    sign_in_as identity

    assert_difference -> { User.count }, +1 do
      post users_joins_path, params: { user: { name: "Newart Userbaum" } }
      assert_redirected_to root_path
    end
  end
end
