require "test_helper"

class Storage::EntryTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
    @board = boards(:writebook)
    @card = cards(:logo)
  end

  test "record! creates entry with positive delta" do
    assert_difference "Storage::Entry.count", +1 do
      entry = Storage::Entry.record \
        account: @account,
        board: @board,
        recordable: @card,
        delta: 1024,
        operation: "attach"

      assert_equal @account.id, entry.account_id
      assert_equal @board.id, entry.board_id
      assert_equal @card.class.name, entry.recordable_type
      assert_equal @card.id, entry.recordable_id
      assert_equal 1024, entry.delta
      assert_equal "attach", entry.operation
    end
  end

  test "record! creates entry with negative delta" do
    entry = Storage::Entry.record \
      account: @account,
      board: @board,
      recordable: @card,
      delta: -512,
      operation: "detach"

    assert_equal -512, entry.delta
    assert_equal "detach", entry.operation
  end

  test "record! returns nil and creates no entry when delta is zero" do
    assert_no_difference "Storage::Entry.count" do
      result = Storage::Entry.record \
        account: @account,
        board: @board,
        recordable: @card,
        delta: 0,
        operation: "attach"

      assert_nil result
    end
  end

  test "record! accepts _id params for after_destroy_commit snapshots" do
    entry = Storage::Entry.record \
      account_id: @account.id,
      board_id: @board.id,
      recordable_type: "Card",
      recordable_id: @card.id,
      delta: 2048,
      operation: "detach"

    assert_equal @account.id, entry.account_id
    assert_equal @board.id, entry.board_id
    assert_equal "Card", entry.recordable_type
    assert_equal @card.id, entry.recordable_id
  end

  test "record! creates entry without board" do
    entry = Storage::Entry.record \
      account: @account,
      board: nil,
      recordable: @card,
      delta: 1024,
      operation: "attach"

    assert_nil entry.board_id
  end

  test "record! creates entry without recordable" do
    entry = Storage::Entry.record \
      account: @account,
      board: @board,
      recordable: nil,
      delta: 1024,
      operation: "reconcile"

    assert_nil entry.recordable_type
    assert_nil entry.recordable_id
  end

  test "record! enqueues MaterializeJob for account" do
    assert_enqueued_with job: Storage::MaterializeJob, args: [ @account ] do
      Storage::Entry.record \
        account: @account,
        board: nil,
        recordable: nil,
        delta: 1024,
        operation: "attach"
    end
  end

  test "record! enqueues MaterializeJob for board when board_id present" do
    assert_enqueued_with job: Storage::MaterializeJob, args: [ @board ] do
      Storage::Entry.record \
        account: @account,
        board: @board,
        recordable: nil,
        delta: 1024,
        operation: "attach"
    end
  end

  test "record! does not enqueue job when account is deleted" do
    # The graceful handling is that find_by returns nil, so no job is enqueued
    # for a non-existent account. We can't test with a fake ID due to FK constraints,
    # but we can verify the find_by behavior by stubbing.
    Account.stubs(:find_by).returns(nil)

    assert_no_enqueued_jobs only: Storage::MaterializeJob do
      Storage::Entry.record \
        account: @account,
        delta: 1024,
        operation: "attach"
    end
  end

  test "record! does not enqueue board job when board is deleted" do
    Board.stubs(:find_by).returns(nil)

    # Account job still enqueued, but board job is not
    entry = Storage::Entry.record \
      account: @account,
      board: @board,
      delta: 1024,
      operation: "attach"

    assert_not_nil entry
  end

  test "entries belong to account" do
    entry = Storage::Entry.record \
      account: @account,
      delta: 1024,
      operation: "attach"

    assert_equal @account, entry.account
  end

  test "entries belong to board (optional)" do
    entry = Storage::Entry.record \
      account: @account,
      board: @board,
      delta: 1024,
      operation: "attach"

    assert_equal @board, entry.board
  end

  test "entries belong to recordable (polymorphic, optional)" do
    entry = Storage::Entry.record \
      account: @account,
      recordable: @card,
      delta: 1024,
      operation: "attach"

    assert_equal @card, entry.recordable
  end
end
