require "test_helper"

class Sessions::MagicLinksControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    untenanted do
      get session_magic_link_url

      assert_response :redirect, "Without an email address pending authentication, should redirect"
      assert_redirected_to new_session_path
    end

    untenanted do
      post session_path, params: { email_address: "test@example.com" }
      get session_magic_link_url

      assert_response :success
    end
  end

  test "create with sign in code" do
    identity = identities(:kevin)
    magic_link = MagicLink.create!(identity: identity)

    untenanted do
      post session_path, params: { email_address: identity.email_address }
      post session_magic_link_url, params: { code: magic_link.code }

      assert_response :redirect
      assert cookies[:session_token].present?
      assert_redirected_to landing_path, "Should redirect to after authentication path"
      assert_not MagicLink.exists?(magic_link.id), "The magic link should be consumed"
    end
  end

  test "create with sign up code" do
    identity = identities(:kevin)
    magic_link = MagicLink.create!(identity: identity, purpose: :sign_up)

    untenanted do
      post session_path, params: { email_address: identity.email_address }
      post session_magic_link_url, params: { code: magic_link.code }

      assert_response :redirect
      assert cookies[:session_token].present?
      assert_redirected_to new_signup_completion_path, "Should redirect to signup completion"
      assert_not MagicLink.exists?(magic_link.id), "The magic link should be consumed"
    end
  end

  test "create with cross-user code" do
    identity = identities(:kevin)
    other_identity = identities(:jason)
    magic_link = MagicLink.create!(identity: other_identity)

    untenanted do
      post session_path, params: { email_address: identity.email_address }
      post session_magic_link_url, params: { code: magic_link.code }

      assert_redirected_to new_session_path
      assert_not cookies[:session_token].present?
    end
  end

  test "create with invalid code" do
    identity = identities(:kevin)
    magic_link = MagicLink.create!(identity: identity)

    untenanted do
      post session_magic_link_url, params: { code: "INVALID" }
    end

    assert_response :redirect, "Invalid code should redirect"

    expired_link = MagicLink.create!(identity: identity)
    expired_link.update_column(:expires_at, 1.hour.ago)

    post session_magic_link_url, params: { code: expired_link.code }

    assert_response :redirect, "Expired magic link should redirect"
    assert MagicLink.exists?(expired_link.id), "Expired magic link should not be consumed"
  end

  test "create via JSON for sign in" do
    identity = identities(:david)
    magic_link = identity.send_magic_link

    untenanted do
      post session_path(format: :json), params: { email_address: identity.email_address }
      post session_magic_link_path(format: :json), params: { code: magic_link.code }
      assert_response :success
      assert @response.parsed_body["session_token"].present?
      assert_equal false, @response.parsed_body["requires_signup_completion"]
    end
  end

  test "create via JSON for sign up" do
    identity = identities(:david)
    magic_link = identity.send_magic_link(for: :sign_up)

    untenanted do
      post session_path(format: :json), params: { email_address: identity.email_address }
      post session_magic_link_path(format: :json), params: { code: magic_link.code }
      assert_response :success
      assert @response.parsed_body["session_token"].present?
      assert_equal true, @response.parsed_body["requires_signup_completion"]
    end
  end

  test "create via JSON without pending_authentication_token" do
    identity = identities(:david)
    magic_link = identity.send_magic_link

    untenanted do
      post session_magic_link_path(format: :json), params: { code: magic_link.code }
      assert_response :unauthorized
      assert_equal "Enter your email address to sign in.", @response.parsed_body["message"]
    end
  end

  test "create via JSON with invalid code" do
    identity = identities(:david)

    untenanted do
      post session_path(format: :json), params: { email_address: identity.email_address }
      post session_magic_link_path(format: :json), params: { code: "INVALID" }
      assert_response :unauthorized
      assert_equal "Try another code.", @response.parsed_body["message"]
    end
  end

  test "create via JSON with cross-user code" do
    identity = identities(:david)
    other_identity = identities(:jason)
    magic_link = other_identity.send_magic_link

    untenanted do
      post session_path(format: :json), params: { email_address: identity.email_address }
      post session_magic_link_path(format: :json), params: { code: magic_link.code }
      assert_response :unauthorized
      assert_equal "Something went wrong. Please try again.", @response.parsed_body["message"]
    end
  end

  test "create via JSON with expired pending_authentication_token" do
    identity = identities(:david)
    magic_link = identity.send_magic_link

    untenanted do
      travel_to 20.minutes.ago do
        post session_path(format: :json), params: { email_address: identity.email_address }
      end

      post session_magic_link_path(format: :json), params: { code: magic_link.code }
      assert_response :unauthorized
      assert_equal "Enter your email address to sign in.", @response.parsed_body["message"]
    end
  end
end
