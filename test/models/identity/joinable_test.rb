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
end
