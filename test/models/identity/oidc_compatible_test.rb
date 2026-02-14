require "test_helper"

class Identity::OidcCompatibleTest < ActiveSupport::TestCase
  test "find_or_create_from_oidc creates new identity" do
    auth_hash = build_oidc_auth_hash(
      uid: "new-user-123",
      email: "newoidc@example.com"
    )

    identity = Identity.find_or_create_from_oidc(auth_hash)

    assert identity.persisted?
    assert_equal "newoidc@example.com", identity.email_address
    assert_equal "new-user-123", identity.oidc_subject
    assert_equal "oidc", identity.oidc_provider
  end

  test "find_or_create_from_oidc links to existing identity by email" do
    existing = identities(:david)

    auth_hash = build_oidc_auth_hash(
      uid: "link-123",
      email: existing.email_address
    )

    identity = Identity.find_or_create_from_oidc(auth_hash)

    assert_equal existing.id, identity.id
    assert_equal "link-123", identity.oidc_subject
  end

  test "find_or_create_from_oidc finds by oidc_subject" do
    existing = identities(:mike)

    auth_hash = build_oidc_auth_hash(
      uid: existing.oidc_subject,
      email: "different@example.com", # Different email
      email_verified: false
    )

    identity = Identity.find_or_create_from_oidc(auth_hash)

    assert_equal existing.id, identity.id
    # Email should NOT change if not verified
    assert_equal existing.email_address, identity.email_address
  end

  test "find_or_create_from_oidc updates email when verified" do
    existing = identities(:mike)
    new_email = "updated@example.com"

    auth_hash = build_oidc_auth_hash(
      uid: existing.oidc_subject,
      email: new_email,
      email_verified: true
    )

    identity = Identity.find_or_create_from_oidc(auth_hash)

    assert_equal existing.id, identity.id
    assert_equal new_email, identity.email_address
  end

  test "find_or_create_from_oidc returns nil when missing required fields" do
    # Missing uid
    auth_hash = build_oidc_auth_hash(uid: nil, email: "test@example.com")
    assert_nil Identity.find_or_create_from_oidc(auth_hash)

    # Missing email
    auth_hash = build_oidc_auth_hash(uid: "123", email: nil)
    assert_nil Identity.find_or_create_from_oidc(auth_hash)
  end

  private
    def build_oidc_auth_hash(uid:, email:, email_verified: true, name: "Test User")
      OmniAuth::AuthHash.new(
        provider: "oidc",
        uid: uid,
        info: { email: email, name: name },
        extra: { raw_info: { email_verified: email_verified } }
      )
    end
end
