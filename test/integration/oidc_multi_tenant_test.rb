require "test_helper"

class OidcMultiTenantTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:oidc] = nil
  end

  test "User created through OIDC flow can access their account in multi-tenant mode" do
    with_multi_tenant_mode(true) do
      sign_in_via_oidc(uid: "multi-tenant-user", email: "multitenant@example.com")

      identity = Identity.find_by(email_address: "multitenant@example.com")
      assert identity.present?
      assert_equal "multi-tenant-user", identity.oidc_subject

      account = accounts("37s")

      Current.without_account do
        identity.join(account)
      end

      get "#{account.slug}/cards"
      assert_response :success, "User should be able to access their account after OIDC auth"
    end
  end

  test "OIDC user with multiple accounts can access session menu" do
    with_multi_tenant_mode(true) do
      sign_in_via_oidc(uid: "multi-account-user", email: "multiaccounts@example.com")

      identity = Identity.find_by(email_address: "multiaccounts@example.com")

      account1 = accounts("37s")
      account2 = accounts(:initech)

      Current.without_account do
        identity.join(account1)
        identity.join(account2)
      end

      untenanted do
        get session_menu_path
        assert_response :success, "User should be able to access session menu"
      end
    end
  end

  test "OIDC links existing magic link user in multi-tenant mode" do
    with_multi_tenant_mode(true) do
      existing = identities(:david)
      account = accounts("37s")
      user = users(:david)

      assert_equal account, user.account
      assert_equal existing, user.identity

      sign_in_via_oidc(uid: "david-oidc-link", email: existing.email_address)

      existing.reload
      assert_equal "david-oidc-link", existing.oidc_subject
      assert_equal "oidc", existing.oidc_provider

      get "#{account.slug}/cards"
      assert_response :success, "User has access to their original account"
    end
  end
end
