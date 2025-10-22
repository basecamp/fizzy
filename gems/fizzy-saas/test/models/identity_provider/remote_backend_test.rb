require "test_helper"

class IdentityProvider::RemoteBackendTest < ActiveSupport::TestCase
  setup do
    WebMock.stub_request(:post, %r{http://example\.com(:80)?/identities/link})
      .to_return do |request|
        body = JSON.parse(request.body)
        IdentityProvider::LocalBackend.link(email_address: body["email_address"], to: body["to"])
        { status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" } }
      end

    WebMock.stub_request(:post, %r{http://example\.com(:80)?/identities/unlink})
      .to_return do |request|
        body = JSON.parse(request.body)
        IdentityProvider::LocalBackend.unlink(email_address: body["email_address"], from: body["from"])
        { status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" } }
      end

    WebMock.stub_request(:post, %r{http://example\.com(:80)?/identities/change_email_address})
      .to_return do |request|
        body = JSON.parse(request.body)
        IdentityProvider::LocalBackend.change_email_address(from: body["from"], to: body["to"], tenant: body["tenant"])
        { status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" } }
      end

    WebMock.stub_request(:post, %r{http://example\.com(:80)?/identities/send_magic_link})
      .to_return do |request|
        body = JSON.parse(request.body)
        code = IdentityProvider::LocalBackend.send_magic_link(body["email_address"])
        { status: 200, body: { code: code }.to_json, headers: { "Content-Type" => "application/json" } }
      end
  end

  test "link" do
    new_email = "newuser@example.com"
    tenant = ApplicationRecord.current_tenant

    assert_difference -> { Identity.count }, 1 do
      assert_difference -> { Membership.count }, 1 do
        IdentityProvider::RemoteBackend.link(email_address: new_email, to: tenant)
      end
    end

    identity = Identity.find_by(email_address: new_email)
    assert identity.memberships.exists?(tenant: tenant)
  end

  test "unlink" do
    identity = identities(:kevin)
    tenant = ApplicationRecord.current_tenant

    assert_difference -> { Membership.count }, -1 do
      IdentityProvider::RemoteBackend.unlink(email_address: identity.email_address, from: tenant)
    end
  end

  test "change_email_address" do
    identity = identities(:kevin)
    tenant = ApplicationRecord.current_tenant
    new_email = "newemail@example.com"

    IdentityProvider::RemoteBackend.change_email_address(from: identity.email_address, to: new_email, tenant: tenant)

    new_identity = Identity.find_by(email_address: new_email)
    assert new_identity.memberships.exists?(tenant: tenant)
  end

  test "send_magic_link" do
    identity = identities(:kevin)

    assert_difference -> { MagicLink.count }, 1 do
      code = IdentityProvider::RemoteBackend.send_magic_link(identity.email_address)
      assert_equal MagicLink::CODE_LENGTH, code.length
    end

    code = IdentityProvider::RemoteBackend.send_magic_link("nonexistent@example.com")
    assert_nil code
  end

  test "consume_magic_link" do
    identity = identities(:kevin)
    magic_link = identity.send_magic_link

    token = IdentityProvider::RemoteBackend.consume_magic_link(magic_link.code)
    assert_equal identity.signed_id, token.id
    assert_not MagicLink.exists?(magic_link.id)

    token = IdentityProvider::RemoteBackend.consume_magic_link("invalid")
    assert_nil token
  end

  test "token_for" do
    identity = identities(:kevin)

    token = IdentityProvider::RemoteBackend.token_for(identity.email_address)
    assert_equal identity.signed_id, token.id

    token = IdentityProvider::RemoteBackend.token_for("nonexistent@example.com")
    assert_nil token
  end

  test "resolve_token" do
    identity = identities(:kevin)
    token = { "id" => identity.signed_id }

    email = IdentityProvider::RemoteBackend.resolve_token(token)
    assert_equal identity.email_address, email

    email = IdentityProvider::RemoteBackend.resolve_token({ "id" => "invalid" })
    assert_nil email
  end

  test "verify_token" do
    identity = identities(:kevin)
    token = { "id" => identity.signed_id }

    result = IdentityProvider::RemoteBackend.verify_token(token)
    assert_equal identity.signed_id, result.id

    result = IdentityProvider::RemoteBackend.verify_token({ "id" => "invalid" })
    assert_nil result
  end

  test "tenants_for" do
    identity = identities(:kevin)
    token = { "id" => identity.signed_id }

    tenants = IdentityProvider::RemoteBackend.tenants_for(token)
    assert tenants.all? { |t| t.is_a?(IdentityProvider::Tenant) }
    assert_includes tenants.map(&:id), identity.memberships.first.tenant
  end
end
