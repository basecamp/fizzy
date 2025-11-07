require "test_helper"

class Signup::MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = Identity.create!(email_address: "newuser@example.com")
    magic_link = @identity.send_magic_link

    untenanted do
      post session_magic_link_url, params: { code: magic_link.code }
      assert_response :redirect, "Magic link should succeed"

      cookie = cookies.get_cookie "session_token"
      assert_not_nil cookie, "Expected session_token cookie to be set after magic link consumption"
    end
  end

  test "new" do
    untenanted do
      get saas.new_signup_membership_path

      assert_response :success
    end
  end

  test "new with new_user param" do
    untenanted do
      get saas.new_signup_membership_path(signup: { new_user: true })

      assert_response :success
    end
  end

  test "create" do
    untenanted do
      assert_difference -> { Membership.count }, 1 do
        post saas.signup_membership_path, params: {
          signup: {
            full_name: "New User"
          }
        }
      end

      membership = Membership.last
      assert_redirected_to saas.new_signup_completion_path(
        signup: {
          membership_id: membership.signed_id(purpose: :account_creation),
          full_name: "New User",
          account_name: "New's Fizzy"
        }
      )
    end
  end

  test "create with invalid params" do
    untenanted do
      assert_no_difference -> { Membership.count } do
        post saas.signup_membership_path, params: {
          signup: {
            full_name: ""
          }
        }
      end

      assert_response :unprocessable_entity, "Invalid params should return unprocessable entity"
    end
  end
end
