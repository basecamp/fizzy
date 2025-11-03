require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "change_email_address" do
    tenant = ApplicationRecord.current_tenant
    old_identity = identities(:kevin)
    new_email = "kevin.new@37signals.com"

    assert_difference -> { Identity.count }, 1 do
      Membership.change_email_address(from: old_identity.email_address, to: new_email, tenant: tenant)
    end

    new_identity = Identity.find_by(email_address: new_email)
    assert new_identity
    assert new_identity.memberships.exists?(tenant: tenant)
    assert_not old_identity.reload.memberships.exists?(tenant: tenant)
  end
end
