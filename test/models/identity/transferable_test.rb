require "test_helper"

class Identity::TransferableTest < ActiveSupport::TestCase
  test "transfer_id is a string and does not consume the token" do
    identity = identities(:david)

    transfer_id = identity.transfer_id
    assert_kind_of String, transfer_id

    # Minting is a pure read: the generation is untouched and the token still redeems.
    assert_no_difference -> { identity.reload.transfer_token_generation } do
      identity.transfer_id
    end
    assert_equal identity, Identity.find_by_transfer_id(transfer_id)
  end

  test "find_by_transfer_id redeems a valid token" do
    identity = identities(:kevin)

    assert_equal identity, Identity.find_by_transfer_id(identity.transfer_id)
  end

  test "find_by_transfer_id rejects a tampered or malformed token" do
    assert_nil Identity.find_by_transfer_id("invalid_id")
  end

  test "find_by_transfer_id rejects an expired token" do
    identity = identities(:kevin)
    transfer_id = identity.transfer_id

    travel Identity::Transferable::TRANSFER_LINK_EXPIRY_DURATION + 1.second do
      assert_nil Identity.find_by_transfer_id(transfer_id)
    end
  end

  test "a transfer token is single-use: a second redemption is rejected" do
    identity = identities(:kevin)
    transfer_id = identity.transfer_id

    assert_equal identity, Identity.find_by_transfer_id(transfer_id)
    assert_nil Identity.find_by_transfer_id(transfer_id)
  end

  test "regenerating revokes previously issued tokens" do
    identity = identities(:kevin)
    transfer_id = identity.transfer_id

    identity.regenerate_transfer_token

    assert_nil Identity.find_by_transfer_id(transfer_id)
    # A freshly minted token still works after regeneration.
    assert_equal identity, Identity.find_by_transfer_id(identity.transfer_id)
  end

  test "regenerating advances the generation even from a stale in-memory value" do
    identity = identities(:kevin)
    stale = Identity.find(identity.id)

    # Something advances the generation out from under the stale instance.
    identity.regenerate_transfer_token
    current_transfer_id = identity.transfer_id

    # The stale instance regenerates unconditionally: it must still advance and revoke
    # the current link, not silently no-op on a mismatched generation.
    stale.regenerate_transfer_token

    assert_equal identity.transfer_token_generation + 1, stale.transfer_token_generation
    assert_nil Identity.find_by_transfer_id(current_transfer_id)
  end

  test "consume is a compare-and-swap on the generation" do
    identity = identities(:kevin)
    generation = identity.transfer_token_generation

    # The redemption is an atomic conditional UPDATE keyed on the presented
    # generation, so only the matching generation is consumed and it advances by one.
    assert_equal identity, identity.consume_transfer_token(generation)
    assert_equal generation + 1, identity.reload.transfer_token_generation

    # A stale generation (a replay, or a token superseded by a regenerate) matches no
    # row: nothing is consumed and the counter does not move.
    assert_nil identity.consume_transfer_token(generation)
    assert_equal generation + 1, identity.reload.transfer_token_generation
  end
end
