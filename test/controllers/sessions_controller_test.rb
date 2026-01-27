require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    untenanted do
      get new_session_path
    end

    assert_response :success
  end

  test "new redirects authenticated users" do
    sign_in_as :kevin

    untenanted do
      get new_session_path
      assert_redirected_to root_url
    end
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
      assert_difference -> { MagicLink.count }, +1 do
        assert_difference -> { Identity.count }, +1 do
          post session_path,
            params: { email_address: "nonexistent-#{SecureRandom.hex(6)}@example.com" }
        end
      end

      assert_redirected_to session_magic_link_path
      assert MagicLink.last.for_sign_up?
    end
  end

  test "create for a new user when single tenant mode already has a tenant" do
    with_multi_tenant_mode(false) do
      untenanted do
        assert_no_difference -> { MagicLink.count } do
          assert_no_difference -> { Identity.count } do
            post session_path,
              params: { email_address: "nonexistent-#{SecureRandom.hex(6)}@example.com" }
          end
        end

        assert_redirected_to session_magic_link_path
      end
    end
  end

  test "create with invalid email address" do
    # Avoid Sentry exceptions when attackers try to stuff invalid emails. The browser performs form
    # field validation that should normally prevent this from occurring, so I'm not worried about
    # returning proper validation errors.
    without_action_dispatch_exception_handling do
      untenanted do
        assert_no_difference -> { Identity.count } do
          post session_path, params: { email_address: "not-a-valid-email" }
        end

        assert_response :redirect
        assert_redirected_to new_session_path
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

  test "create via JSON" do
    untenanted do
      post session_path(format: :json), params: { email_address: identities(:david).email_address }
      assert_response :created
    end
  end

  test "create for a new user via JSON" do
    new_email = "new-user-#{SecureRandom.hex(6)}@example.com"

    untenanted do
      assert_difference -> { Identity.count }, 1 do
        assert_difference -> { MagicLink.count }, 1 do
          post session_path(format: :json), params: { email_address: new_email }
        end
      end
      assert_response :created
      assert @response.parsed_body["pending_authentication_token"].present?
      assert MagicLink.last.for_sign_up?
    end
  end

  test "create with invalid email address via JSON" do
    untenanted do
      assert_no_difference -> { Identity.count } do
        post session_path(format: :json), params: { email_address: "not-a-valid-email" }
      end
      assert_response :unprocessable_entity
    end
  end

  test "destroy via JSON" do
    sign_in_as :kevin

    untenanted do
      delete session_path(format: :json)

      assert_response :no_content
      assert_not cookies[:session_token].present?
    end
  end
end
