require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "destroy" do
    sign_in_as :kevin

    delete session_path

    assert_redirected_to new_session_path
    assert_not cookies[:session_token].present?
  end

  test "new" do
    untenanted do
      get new_session_path

      assert_response :success
    end
  end

  test "create with existing membership" do
    untenanted do
      membership = memberships(:kevin_in_37signals)

      assert_difference -> { MagicLink.count }, 1 do
        post session_path, params: { email_address: membership.email_address }
      end

      assert_redirected_to session_magic_link_path
    end
  end

  test "create with non-existent email" do
    untenanted do
      assert_no_difference -> { MagicLink.count } do
        post session_path, params: { email_address: "nonexistent@example.com" }
      end

      assert_redirected_to session_magic_link_path
    end
  end
end
