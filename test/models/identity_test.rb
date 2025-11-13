require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "send_magic_link" do
    identity = identities(:david)

    assert_emails 1 do
      magic_link = identity.send_magic_link
      assert_not_nil magic_link
      assert_equal identity, magic_link.identity
    end
  end

  test "staff?" do
    assert Identity.new(email_address: "test@37signals.com").staff?
    assert Identity.new(email_address: "test@basecamp.com").staff?
    assert_not Identity.new(email_address: "test@example.com").staff?
  end

  test "join creates membership and user for account" do
    identity = identities(:david)
    account = accounts(:initech)

    assert_difference [ "Membership.count", "User.count" ], 1 do
      identity.join(account)
    end

    membership = identity.memberships.order(created_at: :desc).first
    assert_equal account.external_account_id.to_s, membership.tenant

    user = account.users.order(created_at: :desc).first
    assert_equal membership, user.membership
    assert_equal identity.email_address, user.name
  end
end
