require "test_helper"

class Identity::TransferableTest < ActiveSupport::TestCase
  test "transfer is nil until a link is minted" do
    assert_nil identities(:david).transfer
  end

  test "transfer_id mints a redeemable token" do
    identity = identities(:david)

    token = identity.transfer_id

    assert_kind_of String, token
    assert_equal identity, Identity.find_by_transfer_id(token)
  end

  test "find_by_transfer_id rejects an unknown token" do
    assert_nil Identity.find_by_transfer_id("nonexistent")
  end

  test "find_by_transfer_id rejects an expired token" do
    token = identities(:kevin).transfer_id

    travel Identity::Transfer::EXPIRATION_TIME + 1.second do
      assert_nil Identity.find_by_transfer_id(token)
    end
  end

  test "a transfer token is single-use: a second redemption is rejected" do
    identity = identities(:kevin)
    token = identity.transfer_id

    assert_equal identity, Identity.find_by_transfer_id(token)
    assert_nil Identity.find_by_transfer_id(token)
  end

  test "regenerating revokes previously issued tokens and mints a fresh one" do
    identity = identities(:kevin)
    old_token = identity.transfer_id

    identity.regenerate_transfer_token

    assert_nil Identity.find_by_transfer_id(old_token)
    assert_equal identity, Identity.find_by_transfer_id(identity.transfer.token)
  end

  test "regenerating collapses every outstanding transfer into exactly one" do
    identity = identities(:kevin)
    first = identity.transfer_id
    second = identity.transfers.create!.token

    identity.regenerate_transfer_token

    assert_equal 1, identity.transfers.active.count
    assert_nil Identity.find_by_transfer_id(first)
    assert_nil Identity.find_by_transfer_id(second)
  end
end
