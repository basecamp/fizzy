require "test_helper"

class Identity::JoinableTest < ActiveSupport::TestCase
  test "join creates a new user and returns true" do
    identity = identities(:david)

    assert_difference -> { User.count }, 1 do
      result = identity.join(accounts(:initech))
      assert result, "join should return true when creating a new user"
    end

    user = identity.users.find_by!(account: accounts(:initech))
    assert_equal identity.email_address, user.name
  end

  test "join with custom attributes" do
    identity = identities(:mike)

    result = identity.join(accounts("37s"), name: "Mike")
    assert result

    user = identity.users.find_by!(account: accounts("37s"))
    assert_equal "Mike", user.name
  end

  test "join returns false if user already exists" do
    identity = identities(:david)
    account = accounts("37s")

    assert identity.users.exists?(account: account), "David should already be a member of 37s"

    assert_no_difference -> { User.count } do
      result = identity.join(account)
      assert_not result, "join should return false when user already exists"
    end
  end

  test "join reactivates a deactivated user" do
    identity = identities(:kevin)
    account = accounts("37s")
    user = users(:kevin)

    user.stubs(:close_remote_connections)
    user.deactivate

    assert_not user.reload.active?, "user should be inactive after deactivation"
    assert_empty user.accesses, "user should have no accesses after deactivation"
    assert_equal identity.id, user.identity_id, "identity link should be preserved after deactivation"

    assert_no_difference -> { User.count } do
      result = identity.join(account)
      assert_not result, "join should return false for reactivation"
    end

    user.reload
    assert user.active?, "user should be active after reactivation"
    assert user.accesses.any?, "user should have accesses restored after reactivation"
  end
end
