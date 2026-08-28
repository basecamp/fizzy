require "test_helper"

class Identity::TransferTest < ActiveSupport::TestCase
  test "consume returns the transfer once, then nothing" do
    transfer = identities(:kevin).transfers.create!

    assert_equal transfer, Identity::Transfer.consume(transfer.token)
    assert_nil Identity::Transfer.consume(transfer.token)
  end

  test "consume ignores an expired transfer" do
    transfer = identities(:kevin).transfers.create!

    travel Identity::Transfer::EXPIRATION_TIME + 1.second do
      assert_nil Identity::Transfer.consume(transfer.token)
    end
  end

  test "consume is atomic: only one holder of a shared token wins" do
    transfer = identities(:kevin).transfers.create!
    one = Identity::Transfer.active.find_by(token: transfer.token)
    two = Identity::Transfer.active.find_by(token: transfer.token)

    assert_equal transfer, one.consume
    assert_nil two.consume
  end

  test "cleanup deletes only stale transfers" do
    fresh = identities(:kevin).transfers.create!
    stale = identities(:david).transfers.create!
    stale.update_column :created_at, (Identity::Transfer::EXPIRATION_TIME + 1.hour).ago

    Identity::Transfer.cleanup

    assert Identity::Transfer.exists?(fresh.id)
    assert_not Identity::Transfer.exists?(stale.id)
  end
end
