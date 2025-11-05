require "test_helper"

class Memberships::UnlinkControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    untenanted do
      sign_in_as :kevin

      membership = memberships(:kevin_in_37signals)
      signed_id = membership.signed_id(purpose: :unlinking)

      get unlink_membership_path(membership_id: signed_id)
      assert_response :success
    end
  end

  test "create" do
    untenanted do
      sign_in_as :kevin

      membership = memberships(:kevin_in_37signals)
      signed_id = membership.signed_id(purpose: :unlinking)

      assert_difference -> { Membership.count }, -1 do
        post unlink_membership_path(membership_id: signed_id)
      end

      assert_redirected_to session_menu_path
    end
  end
end
