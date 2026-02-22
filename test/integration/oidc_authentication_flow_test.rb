require "test_helper"

class OidcAuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:oidc] = nil
  end

  test "complete OIDC sign in flow for new user" do
    sign_in_via_oidc(uid: "cory-123", email: "cory@73signals.com")

    identity = Identity.find_by(email_address: "cory@73signals.com")
    assert identity.present?
    assert_equal "cory-123", identity.oidc_subject
    assert_equal "oidc", identity.oidc_provider
  end

  test "OIDC sign in links to existing magic link user" do
    existing = identities(:david)
    original_count = Identity.count

    sign_in_via_oidc(uid: "link-789", email: existing.email_address)

    # Should link to existing Identity
    assert_equal original_count, Identity.count

    existing.reload
    assert_equal "link-789", existing.oidc_subject
    assert_equal "oidc", existing.oidc_provider
  end

  test "OIDC user can sign in multiple times" do
    existing = identities(:mike)

    sign_in_via_oidc(uid: "repeat-user", email: existing.email_address)
    first_session_token = cookies[:session_token]

    sign_out

    sign_in_via_oidc(uid: "repeat-user", email: existing.email_address)
    second_session_token = cookies[:session_token]

    assert_not_equal first_session_token, second_session_token
  end
end
