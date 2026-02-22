require "test_helper"

class Sessions::OidcControllerTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:oidc] = nil
  end

  test "successful authentication creates session" do
    sign_in_via_oidc(
      uid: "oidc-123",
      email: "test@example.com",
      email_verified: true
    )

    untenanted do
      identity = Identity.find_by(email_address: "test@example.com")
      assert identity.present?
      assert_equal "oidc-123", identity.oidc_subject
      assert_equal "oidc", identity.oidc_provider
    end
  end

  test "links OIDC to existing identity by email" do
    existing = identities(:david)

    sign_in_via_oidc(
      uid: "oidc-456",
      email: existing.email_address,
      email_verified: true
    )

    untenanted do
      existing.reload
      assert_equal "oidc-456", existing.oidc_subject
      assert_equal "oidc", existing.oidc_provider
    end
  end

  test "handles authentication failure" do
    OmniAuth.config.mock_auth[:oidc] = :invalid_credentials

    untenanted do
      get "/auth/failure", params: { message: "invalid_credentials" }

      assert_redirected_to new_session_path
      assert_not cookies[:session_token].present?
    end
  end

  test "handles missing auth hash" do
    untenanted do
      # auth_hash will be nil
      post "/auth/oidc/callback"

      assert_redirected_to new_session_path
      assert_match flash[:alert], "OIDC authentication failed."
    end
  end

  test "handles identity creation failure" do
    auth_hash = OmniAuth::AuthHash.new(
      provider: "oidc",
      uid: ""
    )

    OmniAuth.config.mock_auth[:oidc] = auth_hash

    untenanted do
      post "/auth/oidc/callback", env: { "omniauth.auth" => auth_hash }

      assert_redirected_to new_session_path
      assert_not cookies[:session_token].present?
      assert_match flash[:alert], "Error during OIDC authentication."
    end
  end
end
