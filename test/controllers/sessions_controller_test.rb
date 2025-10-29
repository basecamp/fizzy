require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "destroy" do
    untenanted do
      sign_in_as :kevin

      delete session_path

      assert_redirected_to new_session_path
      assert_not cookies[:session_token].present?
    end
  end

  test "new" do
    untenanted do
      get new_session_path

      assert_response :success
    end
  end

  test "create" do
    untenanted do
      identity = identities(:kevin)

      assert_difference -> { MagicLink.count }, 1 do
        post session_path, params: { email_address: identity.email_address }
      end

      assert_redirected_to session_magic_link_path
    end

    untenanted do
      assert_no_difference -> { MagicLink.count } do
        post session_path, params: { email_address: "nonexistent@example.com" }
      end

      assert_redirected_to session_magic_link_path
    end
  end
end
