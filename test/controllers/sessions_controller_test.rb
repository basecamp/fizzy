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
    end
  end

  if Fizzy.saas?
    test "create for a new user" do
      untenanted do
        assert_difference -> { Identity.count }, +1 do
          assert_difference -> { MagicLink.count }, +1 do
            post session_path,
              params: { email_address: "nonexistent-#{SecureRandom.hex(6)}@example.com" },
              headers: http_basic_auth_headers("testname", "testpassword")
          end
        end

        assert_redirected_to session_magic_link_path
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

  private
    def http_basic_auth_headers(user, password)
      { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(user, password) }
    end
end
