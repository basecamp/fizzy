require "test_helper"

class Memberships::EmailAddresses::ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    untenanted do
      membership = memberships(:kevin_in_37signals)

      get email_address_confirmation_path(
        membership_id: membership.id,
        email_address_token: "dummy_token"
      )

      assert_response :success
    end
  end

  test "create" do
    untenanted do
      membership = memberships(:kevin_in_37signals)
      old_identity = membership.identity
      new_email = "updated@example.com"

      # Generate a real token
      token = membership.send(:generate_email_address_change_token, to: new_email)

      assert_difference -> { Identity.count }, 1 do
        post email_address_confirmation_path(
          membership_id: membership.id,
          email_address_token: token
        ),
        params: { email_address_token: token }
      end

      membership.reload
      assert_equal new_email, membership.identity.email_address
      assert_not_equal old_identity.id, membership.identity_id

      assert cookies[:session_token].present?, "Should have started new session"
      assert_redirected_to edit_user_url(script_name: "/#{membership.tenant}", id: membership.user)
    end
  end
end
