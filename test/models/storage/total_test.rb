require "test_helper"

class Storage::TotalTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
    @board = boards(:writebook)
  end

  test "pending_entries returns all entries when no cursor" do
    # Create some entries
    3.times do |i|
      Storage::Entry.record \
        account: @account,
        delta: 1024 * (i + 1),
        operation: "attach"
    end

    total = @account.create_storage_total!
    assert_nil total.last_entry_id

    assert_equal 3, total.pending_entries.count
  end

  test "pending_entries returns only entries after cursor" do
    # Create first entry and set cursor
    entry1 = Storage::Entry.record(account: @account, delta: 1024, operation: "attach")
    total = @account.create_storage_total!(last_entry_id: entry1.id, bytes_stored: 1024)

    # Advance time to ensure UUIDv7 timestamps sort correctly
    travel 1.second

    # Create more entries AFTER cursor is set
    entry2 = Storage::Entry.record(account: @account, delta: 2048, operation: "attach")
    travel 1.second
    entry3 = Storage::Entry.record(account: @account, delta: 512, operation: "attach")

    pending = total.pending_entries
    assert_equal 2, pending.count
    assert_includes pending, entry2
    assert_includes pending, entry3
    assert_not_includes pending, entry1
  end

  test "current_usage returns snapshot value when no pending entries" do
    total = @account.create_storage_total!(bytes_stored: 5000)

    # No entries exist, so nothing pending
    assert_equal 5000, total.current_usage
  end

  test "current_usage sums snapshot and pending entries" do
    # Create first entry and set cursor
    entry1 = Storage::Entry.record(account: @account, delta: 1024, operation: "attach")
    total = @account.create_storage_total!(last_entry_id: entry1.id, bytes_stored: 1024)

    # Small delay to ensure UUIDv7 timestamp component advances
    travel 1.second

    # Create more entries AFTER cursor is set
    Storage::Entry.record(account: @account, delta: 2048, operation: "attach")
    travel 1.second
    Storage::Entry.record(account: @account, delta: -512, operation: "detach")

    # 1024 (snapshot) + 2048 - 512 (pending) = 2560
    assert_equal 2560, total.current_usage
  end

  test "belongs to owner polymorphically" do
    account_total = Storage::Total.create!(owner: @account)
    assert_equal @account, account_total.owner

    board_total = Storage::Total.create!(owner: @board)
    assert_equal @board, board_total.owner
  end

  test "unique constraint on owner" do
    Storage::Total.create!(owner: @account)

    assert_raises ActiveRecord::RecordNotUnique do
      Storage::Total.create!(owner: @account)
    end
  end
end
