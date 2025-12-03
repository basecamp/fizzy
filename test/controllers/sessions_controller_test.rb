require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    untenanted do
      get new_session_path
    end

    assert_response :success
  end

  test "create" do
    identity = identities(:kevin)

    untenanted do
      assert_difference -> { MagicLink.count }, 1 do
        post session_path, params: { email_address: identity.email_address }
      end

      assert_redirected_to session_magic_link_path
      assert_nil flash[:magic_link_code]
    end
  end

  test "create for a new user" do
    untenanted do
      assert_no_difference -> { MagicLink.count } do
        post session_path,
          params: { email_address: "nonexistent-#{SecureRandom.hex(6)}@example.com" }
      end

      assert_redirected_to session_magic_link_path
    end
  end

  private
    test "destroy" do
      sign_in_as :kevin

      untenanted do
        delete session_path

        assert_redirected_to new_session_path
        assert_not cookies[:session_token].present?
      end
    end
end
