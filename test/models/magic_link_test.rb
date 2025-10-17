require "test_helper"

class MagicLinkTest < ActiveSupport::TestCase
  test "new" do
    magic_link = MagicLink.create!(identity: identities(:kevin))

    assert magic_link.code.present?
    assert_equal MagicLink::CODE_LENGTH, magic_link.code.length
    assert magic_link.expires_at.present?
    assert_in_delta MagicLink::EXPIRATION_TIME.from_now, magic_link.expires_at, 1.second
  end

  test "active" do
    active_link = MagicLink.create!(identity: identities(:kevin))
    expired_link = MagicLink.create!(identity: identities(:kevin))
    expired_link.update_column(:expires_at, 1.hour.ago)

    assert_includes MagicLink.active, active_link
    assert_not_includes MagicLink.active, expired_link
  end

  test "stale" do
    active_link = MagicLink.create!(identity: identities(:kevin))
    expired_link = MagicLink.create!(identity: identities(:kevin))
    expired_link.update_column(:expires_at, 1.hour.ago)

    assert_includes MagicLink.stale, expired_link
    assert_not_includes MagicLink.stale, active_link
  end

  test "consume" do
    magic_link = MagicLink.create!(identity: identities(:kevin))
    code_with_spaces = magic_link.code.downcase.chars.join(" ")

    identity = MagicLink.consume(code_with_spaces)
    assert_equal identities(:kevin), identity
    assert_not MagicLink.exists?(magic_link.id)

    expired_link = MagicLink.create!(identity: identities(:kevin))
    expired_link.update_column(:expires_at, 1.hour.ago)
    assert_nil MagicLink.consume(expired_link.code)
    assert MagicLink.exists?(expired_link.id)

    assert_nil MagicLink.consume("INVALID")
    assert_nil MagicLink.consume(nil)
  end

  test "cleanup" do
    active_link = MagicLink.create!(identity: identities(:kevin))
    expired_link = MagicLink.create!(identity: identities(:kevin))
    expired_link.update_column(:expires_at, 1.hour.ago)

    MagicLink.cleanup

    assert MagicLink.exists?(active_link.id)
    assert_not MagicLink.exists?(expired_link.id)
  end
end
