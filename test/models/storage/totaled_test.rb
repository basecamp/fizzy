require "test_helper"

class Storage::TotaledTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @account = accounts("37s")
    @board = boards(:writebook)
  end


  # bytes_used (fast snapshot)

  test "bytes_used returns 0 when no storage_total exists" do
    assert_nil @account.storage_total
    assert_equal 0, @account.bytes_used
  end

  test "bytes_used returns snapshot value" do
    @account.create_storage_total!(bytes_stored: 10_000)
    assert_equal 10_000, @account.bytes_used
  end

  test "bytes_used does not include pending entries (fast path)" do
    @account.create_storage_total!(bytes_stored: 1000)

    # Create pending entry (not materialized)
    Storage::Entry.record(account: @account, delta: 500, operation: "attach")

    # bytes_used is fast path - only reads snapshot
    assert_equal 1000, @account.bytes_used
  end


  # bytes_used_exact (snapshot + pending)

  test "bytes_used_exact creates storage_total if missing" do
    assert_nil @account.storage_total

    @account.bytes_used_exact

    assert_not_nil @account.reload.storage_total
  end

  test "bytes_used_exact includes pending entries" do
    # Create first entry and set cursor at that entry
    entry = Storage::Entry.record(account: @account, delta: 500, operation: "attach")
    @account.create_storage_total!(bytes_stored: 500, last_entry_id: entry.id)

    # Small delay to ensure UUIDv7 timestamp advances
    travel 1.second

    # Create pending entry AFTER cursor
    Storage::Entry.record(account: @account, delta: 256, operation: "attach")

    # 500 (snapshot) + 256 (pending) = 756
    assert_equal 756, @account.bytes_used_exact
  end

  test "bytes_used_exact returns 0 when no entries and no snapshot" do
    assert_equal 0, @account.bytes_used_exact
  end


  # materialize_storage

  test "materialize_storage creates storage_total if missing" do
    assert_nil @account.storage_total

    Storage::Entry.record(account: @account, delta: 1024, operation: "attach")
    @account.materialize_storage

    total = @account.reload.storage_total
    assert_not_nil total
    assert_equal 1024, total.bytes_stored
  end

  test "materialize_storage processes all pending entries" do
    Storage::Entry.record(account: @account, delta: 1000, operation: "attach")
    Storage::Entry.record(account: @account, delta: 2000, operation: "attach")
    Storage::Entry.record(account: @account, delta: -500, operation: "detach")

    @account.materialize_storage

    assert_equal 2500, @account.storage_total.bytes_stored
    assert_equal 0, @account.storage_total.pending_entries.count
  end

  test "materialize_storage updates cursor to latest entry" do
    entry1 = Storage::Entry.record(account: @account, delta: 1000, operation: "attach")
    entry2 = Storage::Entry.record(account: @account, delta: 500, operation: "attach")

    @account.materialize_storage

    assert_equal entry2.id, @account.storage_total.last_entry_id
  end

  test "materialize_storage is idempotent when no new entries" do
    Storage::Entry.record(account: @account, delta: 1000, operation: "attach")
    @account.materialize_storage

    initial_bytes = @account.storage_total.bytes_stored
    initial_cursor = @account.storage_total.last_entry_id

    @account.materialize_storage

    assert_equal initial_bytes, @account.storage_total.bytes_stored
    assert_equal initial_cursor, @account.storage_total.last_entry_id
  end

  test "materialize_storage processes only entries since cursor" do
    entry1 = Storage::Entry.record(account: @account, delta: 1000, operation: "attach")
    @account.materialize_storage

    assert_equal 1000, @account.storage_total.bytes_stored

    # Small delay to ensure UUIDv7 timestamp advances
    travel 1.second

    # Add more entries
    Storage::Entry.record(account: @account, delta: 500, operation: "attach")
    @account.materialize_storage

    assert_equal 1500, @account.storage_total.bytes_stored
  end

  test "materialize_storage does nothing when no entries" do
    @account.materialize_storage

    total = @account.reload.storage_total
    assert_not_nil total
    assert_equal 0, total.bytes_stored
    assert_nil total.last_entry_id
  end

  test "materialize_storage handles concurrent calls safely" do
    # Pre-create storage_total to avoid unique constraint race
    @account.create_storage_total!

    Storage::Entry.record(account: @account, delta: 1000, operation: "attach")

    # Simulate concurrent materialization
    threads = 3.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          @account.materialize_storage
        end
      end
    end
    threads.each(&:join)

    # Should still have correct total
    assert_equal 1000, @account.reload.storage_total.bytes_stored
  end


  # storage_entries association

  test "account has storage_entries association" do
    entry = Storage::Entry.record(account: @account, delta: 1024, operation: "attach")

    assert_includes @account.storage_entries, entry
  end

  test "board has storage_entries association" do
    entry = Storage::Entry.record(account: @account, board: @board, delta: 1024, operation: "attach")

    assert_includes @board.storage_entries, entry
  end


  # storage_total association

  test "storage_total is destroyed when owner is destroyed" do
    @account.create_storage_total!(bytes_stored: 1000)
    total_id = @account.storage_total.id

    # Create a new account to destroy (don't destroy fixtures)
    new_account = Account.create!(name: "Temp Account")
    new_account.create_storage_total!(bytes_stored: 500)
    storage_total_id = new_account.storage_total.id

    new_account.destroy!

    assert_not Storage::Total.exists?(storage_total_id)
  end


  # Board-specific tests

  test "board bytes_used works independently of account" do
    # Create entries for both account and board
    Storage::Entry.record(account: @account, board: nil, delta: 1000, operation: "attach")
    Storage::Entry.record(account: @account, board: @board, delta: 500, operation: "attach")

    @account.materialize_storage
    @board.materialize_storage

    # Account sees all its entries (1000 + 500 = 1500)
    assert_equal 1500, @account.bytes_used

    # Board only sees entries with its board_id (500)
    assert_equal 500, @board.bytes_used
  end

  test "board and account have independent cursors" do
    entry1 = Storage::Entry.record(account: @account, board: @board, delta: 1000, operation: "attach")

    @account.materialize_storage
    # Board not yet materialized

    entry2 = Storage::Entry.record(account: @account, board: @board, delta: 500, operation: "attach")

    # Account cursor at entry1, board has no cursor yet
    assert_equal entry1.id, @account.storage_total.last_entry_id

    @board.materialize_storage

    # Board cursor now at entry2
    assert_equal entry2.id, @board.storage_total.last_entry_id
    assert_equal 1500, @board.bytes_used
  end


  # reconcile_storage

  test "reconcile_storage creates entry for drift" do
    board = @account.boards.create!(name: "Test Board", creator: users(:david))
    card = board.cards.create!(title: "Test Card", creator: users(:david))
    card.image.attach io: StringIO.new("x" * 1000), filename: "test.png", content_type: "image/png"

    # Delete entry to simulate drift
    Storage::Entry.where(board: board).delete_all

    assert_difference "Storage::Entry.count", +1 do
      board.reconcile_storage
    end

    entry = Storage::Entry.find_by(board: board, operation: "reconcile")
    assert_equal 1000, entry.delta
  end

  test "reconcile_storage no-op when ledger matches reality" do
    board = @account.boards.create!(name: "Test Board", creator: users(:david))
    card = board.cards.create!(title: "Test Card", creator: users(:david))
    card.image.attach io: StringIO.new("x" * 1000), filename: "test.png", content_type: "image/png"

    assert_no_difference "Storage::Entry.where(operation: 'reconcile').count" do
      board.reconcile_storage
    end
  end

  test "reconcile_storage handles empty board" do
    board = @account.boards.create!(name: "Empty Board", creator: users(:david))

    assert_no_difference "Storage::Entry.count" do
      board.reconcile_storage
    end
  end

  test "reconcile_storage handles negative drift" do
    board = @account.boards.create!(name: "Test Board", creator: users(:david))

    # Create fake ledger entry with no real attachment
    Storage::Entry.create! \
      account_id: @account.id,
      board_id: board.id,
      delta: 5000,
      operation: "attach"

    board.reconcile_storage

    entry = Storage::Entry.find_by(board: board, operation: "reconcile")
    assert_not_nil entry
    assert_equal(-5000, entry.delta)
  end

  test "reconcile_storage aborts when entry added during scan" do
    board = @account.boards.create!(name: "Test Board", creator: users(:david))
    card = board.cards.create!(title: "Test Card", creator: users(:david))
    card.image.attach io: StringIO.new("x" * 1000), filename: "test.png", content_type: "image/png"

    # Delete entry to create drift
    Storage::Entry.where(board: board).delete_all

    # Intercept calculate_real_storage_bytes to insert a new entry mid-scan,
    # faithfully simulating a concurrent upload that changes the cursor
    board.define_singleton_method(:calculate_real_storage_bytes) do
      Storage::Entry.create!(
        account_id: account.id,
        board_id: id,
        delta: 500,
        operation: "attach"
      )
      super()
    end

    # Should abort and return false without creating reconcile entry
    assert_no_difference "Storage::Entry.where(operation: 'reconcile').count" do
      result = board.reconcile_storage
      assert_equal false, result
    end
  end

  test "reconcile_storage returns true on success" do
    board = @account.boards.create!(name: "Test Board", creator: users(:david))

    result = board.reconcile_storage

    assert_equal true, result
  end


  # ensure_storage_total race safety

  test "ensure_storage_total handles concurrent creation" do
    @account.storage_total&.destroy

    threads = 3.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          @account.bytes_used_exact
        end
      end
    end

    threads.each(&:join)
    assert_equal 1, Storage::Total.where(owner: @account).count
  end


  # per-attachment reconcile

  test "reconcile counts each attachment separately" do
    board = @account.boards.create!(name: "Test", creator: users(:david))

    # Create 3 distinct blobs (one per card) - no reuse
    file = file_fixture("moon.jpg")
    expected_bytes = file.size

    3.times do |i|
      blob = ActiveStorage::Blob.create_and_upload! \
        io: file.open,
        filename: "image_#{i}.jpg",
        content_type: "image/jpeg"

      embed = ActionText::Attachment.from_attachable(blob).to_html
      board.cards.create!(title: "Card #{i}", description: "<p>#{embed}</p>", creator: users(:david))
    end

    Storage::Entry.where(board: board).delete_all
    board.reconcile_storage

    entry = Storage::Entry.find_by(board: board, operation: "reconcile")
    # 3 attachments x file_size bytes
    assert_equal expected_bytes * 3, entry.delta
  end
end
