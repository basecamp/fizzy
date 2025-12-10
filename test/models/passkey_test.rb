require "test_helper"

class PasskeyTest < ActiveSupport::TestCase
  test "belongs to identity" do
    passkey = Passkey.new(
      identity: identities(:kevin),
      external_id: "test-external-id",
      public_key: "test-public-key"
    )

    assert passkey.valid?
    assert_equal identities(:kevin), passkey.identity
  end

  test "requires external_id" do
    passkey = Passkey.new(
      identity: identities(:kevin),
      public_key: "test-public-key"
    )

    assert_not passkey.valid?
    assert_includes passkey.errors[:external_id], "can't be blank"
  end

  test "requires public_key" do
    passkey = Passkey.new(
      identity: identities(:kevin),
      external_id: "test-external-id"
    )

    assert_not passkey.valid?
    assert_includes passkey.errors[:public_key], "can't be blank"
  end

  test "external_id must be unique" do
    Passkey.create!(
      identity: identities(:kevin),
      external_id: "unique-external-id",
      public_key: "test-public-key"
    )

    duplicate = Passkey.new(
      identity: identities(:david),
      external_id: "unique-external-id",
      public_key: "different-public-key"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "sign_count defaults to zero" do
    passkey = Passkey.create!(
      identity: identities(:kevin),
      external_id: "test-external-id",
      public_key: "test-public-key"
    )

    assert_equal 0, passkey.sign_count
  end

  test "identity has many passkeys" do
    identity = identities(:kevin)

    passkey1 = Passkey.create!(
      identity: identity,
      external_id: "external-id-1",
      public_key: "public-key-1",
      name: "iPhone"
    )

    passkey2 = Passkey.create!(
      identity: identity,
      external_id: "external-id-2",
      public_key: "public-key-2",
      name: "MacBook"
    )

    assert_includes identity.passkeys, passkey1
    assert_includes identity.passkeys, passkey2
  end

  test "destroying identity destroys passkeys" do
    identity = Identity.create!(email_address: "passkey-test@example.com")

    passkey = Passkey.create!(
      identity: identity,
      external_id: "test-external-id",
      public_key: "test-public-key"
    )

    identity.destroy

    assert_not Passkey.exists?(passkey.id)
  end
end
