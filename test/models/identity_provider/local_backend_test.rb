require "test_helper"

class IdentityProvider::LocalBackendTest < ActiveSupport::TestCase
  test "link" do
    new_email = "newuser@example.com"
    tenant = ApplicationRecord.current_tenant

    assert_difference -> { Identity.count }, 1 do
      assert_difference -> { Membership.count }, 1 do
        IdentityProvider::LocalBackend.link(email_address: new_email, to: tenant)
      end
    end

    identity = Identity.find_by(email_address: new_email)
    assert identity.memberships.exists?(tenant: tenant), "creates membership for tenant"
  end

  test "unlink" do
    identity = identities(:kevin)
    tenant = ApplicationRecord.current_tenant

    assert_difference -> { Membership.count }, -1 do
      IdentityProvider::LocalBackend.unlink(email_address: identity.email_address, from: tenant)
    end

    assert_not identity.reload.memberships.exists?(tenant: tenant), "removes membership from tenant"
  end

  test "change_email_address" do
    identity = identities(:kevin)
    tenant = ApplicationRecord.current_tenant
    new_email = "newemail@example.com"

    IdentityProvider::LocalBackend.change_email_address(from: identity.email_address, to: new_email, tenant: tenant)

    assert_not identity.reload.memberships.exists?(tenant: tenant), "removes old identity membership"
    new_identity = Identity.find_by(email_address: new_email)
    assert new_identity.memberships.exists?(tenant: tenant), "creates new identity membership"
  end

  test "send_magic_link" do
    identity = identities(:kevin)

    assert_difference -> { MagicLink.count }, 1 do
      code = IdentityProvider::LocalBackend.send_magic_link(identity.email_address)
      assert_equal MagicLink::CODE_LENGTH, code.length, "returns code of correct length"
    end

    code = IdentityProvider::LocalBackend.send_magic_link("nonexistent@example.com")
    assert_nil code, "returns nil for non-existent email"
  end

  test "consume_magic_link" do
    identity = identities(:kevin)
    magic_link = identity.send_magic_link

    token = IdentityProvider::LocalBackend.consume_magic_link(magic_link.code)
    assert_equal identity.signed_id, token.id, "returns token for valid code"
    assert_not MagicLink.exists?(magic_link.id), "deletes magic link after consumption"

    token = IdentityProvider::LocalBackend.consume_magic_link("invalid")
    assert_nil token, "returns nil for invalid code"
  end

  test "token_for" do
    identity = identities(:kevin)

    token = IdentityProvider::LocalBackend.token_for(identity.email_address)
    assert_equal identity.signed_id, token.id, "returns token for existing email"

    token = IdentityProvider::LocalBackend.token_for("nonexistent@example.com")
    assert_nil token, "returns nil for non-existent email"
  end

  test "resolve_token" do
    identity = identities(:kevin)
    token = { "id" => identity.signed_id }

    email = IdentityProvider::LocalBackend.resolve_token(token)
    assert_equal identity.email_address, email, "returns email address from valid token"

    email = IdentityProvider::LocalBackend.resolve_token({ "id" => "invalid" })
    assert_nil email, "returns nil for invalid token"
  end

  test "verify_token" do
    identity = identities(:kevin)
    token = { "id" => identity.signed_id }

    result = IdentityProvider::LocalBackend.verify_token(token)
    assert_equal identity.signed_id, result.id, "returns token from valid token hash"

    result = IdentityProvider::LocalBackend.verify_token({ "id" => "invalid" })
    assert_nil result, "returns nil for invalid token"
  end

  test "tenants_for" do
    identity = identities(:kevin)
    token = { "id" => identity.signed_id }

    tenants = IdentityProvider::LocalBackend.tenants_for(token)
    assert tenants.all? { |t| t.is_a?(IdentityProvider::Tenant) }, "returns Tenant objects"
    assert_includes tenants.map(&:id), identity.memberships.first.tenant, "includes identity's tenant"
  end
end
