require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    untenanted do
      get new_session_path
    end

    assert_response :success
  end

  test "create for existing user without passkeys sends magic link" do
    identity = identities(:jz) # jz has no passkeys in fixtures

    untenanted do
      assert_difference -> { MagicLink.count }, 1 do
        post session_path, params: { email_address: identity.email_address }
      end

      assert_redirected_to session_magic_link_path
    end
  end

  test "create for existing user with passkeys redirects to choice" do
    identity = identities(:kevin) # kevin has a passkey in fixtures

    untenanted do
      assert_no_difference -> { MagicLink.count } do
        post session_path, params: { email_address: identity.email_address }
      end

      assert_redirected_to new_session_choice_path(email: identity.email_address)
    end
  end

  test "create for a new user redirects to signup" do
    untenanted do
      assert_no_difference -> { Identity.count } do
        assert_no_difference -> { MagicLink.count } do
          post session_path,
            params: { email_address: "newuser-#{SecureRandom.hex(6)}@example.com" }
        end
      end

      assert_redirected_to new_signup_path
    end
  end

  test "create with invalid email address" do
    without_action_dispatch_exception_handling do
      untenanted do
        assert_no_difference -> { Identity.count } do
          post session_path, params: { email_address: "not-a-valid-email" }
        end

        assert_response :unprocessable_entity
      end
    end
  end

  test "destroy" do
    sign_in_as :kevin

    untenanted do
      delete session_path

      assert_redirected_to new_session_path
      assert_not cookies[:session_token].present?
    end
  end
end
