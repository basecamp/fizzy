require "test_helper"

class IdentityMembershipTest < ActionDispatch::IntegrationTest
  test "multiple signins on the same browser" do
    # Sign in as kevin to first account
    kevin = users(:kevin)
    sign_in_as(kevin)

    # Then sign in as JZ
    jz = users(:jz)
    set_identity_as(jz)

    expected_membership_ids = [ memberships(:kevin_in_37signals), memberships(:jz_in_37signals) ].map(&:id)
    assert_equal expected_membership_ids.sort, jz.reload.identity.memberships.pluck(:id).sort
  end
end
