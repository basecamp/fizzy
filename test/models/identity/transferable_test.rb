require "test_helper"

class Identity::TransferableTest < ActiveSupport::TestCase
  test "transfer_id" do
    identity = identities(:david)
    transfer_id = identity.transfer_id

    assert_kind_of String, transfer_id
  end

  test "find_by_transfer_id" do
    identity = identities(:kevin)
    transfer_id = identity.transfer_id

    found = Identity.find_by_transfer_id(transfer_id)
    assert_equal identity, found

    found = Identity.find_by_transfer_id("invalid_id")
    assert_nil found

    expired_id = identity.signed_id(purpose: :transfer, expires_in: -1.second)
    found = Identity.find_by_transfer_id(expired_id)
    assert_nil found
  end
end
