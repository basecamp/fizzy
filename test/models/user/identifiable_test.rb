require "test_helper"

class User::IdentifiableTest < ActiveSupport::TestCase
  test "set_identity when token is an identity and user has a matching identity" do
    user = users(:david)
    token_identity = Identity.create!
    token_identity.memberships.create!(user_id: user.id, user_tenant: user.tenant, email_address: user.email_address, account_name: "asdf")
    assert_equal(token_identity, user.identity)

    result = user.set_identity(token_identity)
    user.reload

    assert_equal(token_identity, result)
    assert_equal(token_identity, user.identity)
  end

  test "set_identity when token is an identity and user has no identity" do
    user = users(:david)
    token_identity = Identity.create!
    assert_nil(user.membership)
    assert_nil(user.identity)

    result = user.set_identity(token_identity)
    user.reload

    assert_equal(token_identity, result)
    assert_equal(token_identity, user.identity)
    assert_equal(user.email_address, user.membership.email_address)
    assert_equal(Account.sole.name, user.membership.account_name)
  end

  test "set_identity when token is an identity and user has a different identity" do
    user = users(:david)
    user2 = users(:jz)
    token_identity = Identity.create!
    user_identity = Identity.create!
    user_identity.memberships.create!(user_id: user.id, user_tenant: user.tenant, email_address: user.email_address, account_name: "asdf")
    user_identity.memberships.create!(user_id: user2.id, user_tenant: user2.tenant, email_address: user2.email_address, account_name: "qwer")
    assert_equal(user_identity, user.identity)
    assert_equal(user_identity, user2.identity)

    result = user.set_identity(token_identity)
    user.reload
    user2.reload

    assert_equal(token_identity, result)
    assert_equal(token_identity, user.identity)
    assert_equal(token_identity, user2.identity)

    assert_raises(ActiveRecord::RecordNotFound) do
      user_identity.reload
    end
  end

  test "set_identity when token is nil and user has an identity" do
    user = users(:david)
    user_identity = Identity.create!
    user_identity.memberships.create!(user_id: user.id, user_tenant: user.tenant, email_address: user.email_address, account_name: "asdf")
    assert_equal(user_identity, user.identity)

    result = user.set_identity(nil)
    user.reload

    assert_equal(user_identity, result)
    assert_equal(user_identity, user.identity)
  end

  test "set_identity when token is nil and user has no identity" do
    user = users(:david)
    assert_nil(user.identity)

    result = user.set_identity(nil)
    user.reload

    assert_not_nil(result)
    assert_equal(result, user.identity)
    assert_equal(1, result.memberships.count)
    assert_equal(user.email_address, user.membership.email_address)
    assert_equal(Account.sole.name, user.membership.account_name)
  end
end
