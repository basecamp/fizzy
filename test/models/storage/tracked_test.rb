require "test_helper"

class Storage::TrackedTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @account = accounts("37s")
    @board1 = boards(:writebook)
    @board2 = boards(:private)
    @card = cards(:logo)
  end

  test "storage_bytes returns 0 when no attachments" do
    assert_equal 0, @card.storage_bytes
  end

  test "storage_bytes sums all attachment blob sizes" do
    @card.image.attach io: StringIO.new("x" * 1024), filename: "test.png", content_type: "image/png"
    assert_equal 1024, @card.storage_bytes
  end

  test "board transfer creates transfer_out entry for old board" do
    @card.image.attach io: StringIO.new("x" * 2048), filename: "test.png", content_type: "image/png"
    old_board_id = @card.board_id

    assert_difference "Storage::Entry.count", +2 do
      @card.update!(board: @board2)
    end

    transfer_out = Storage::Entry.find_by(board_id: old_board_id, operation: "transfer_out")

    assert_not_nil transfer_out
    assert_equal -2048, transfer_out.delta
    assert_equal @account.id, transfer_out.account_id
    assert_equal @card.class.name, transfer_out.recordable_type
    assert_equal @card.id, transfer_out.recordable_id
  end

  test "board transfer creates transfer_in entry for new board" do
    @card.image.attach io: StringIO.new("x" * 2048), filename: "test.png", content_type: "image/png"
    @card.update!(board: @board2)

    transfer_in = Storage::Entry.find_by(board_id: @board2.id, operation: "transfer_in")

    assert_not_nil transfer_in
    assert_equal 2048, transfer_in.delta
    assert_equal @account.id, transfer_in.account_id
  end

  test "board transfer does not create entries when no attachments" do
    # Ensure card has no attachments
    @card.image.purge if @card.image.attached?

    # Count only transfer entries
    initial_count = Storage::Entry.where(operation: [ "transfer_out", "transfer_in" ]).count

    @card.update!(board: @board2)

    final_count = Storage::Entry.where(operation: [ "transfer_out", "transfer_in" ]).count
    assert_equal initial_count, final_count
  end

  test "board transfer net effect on account is zero" do
    @card.image.attach io: StringIO.new("x" * 1024), filename: "test.png", content_type: "image/png"

    # Materialize account storage before transfer
    @account.materialize_storage
    initial_account_bytes = @account.bytes_used

    @card.update!(board: @board2)

    # Materialize again
    @account.materialize_storage

    # Account total should be unchanged (transfer_out + transfer_in = 0 for account)
    assert_equal initial_account_bytes, @account.bytes_used
  end

  test "board transfer correctly moves storage between boards" do
    @card.image.attach io: StringIO.new("x" * 1024), filename: "test.png", content_type: "image/png"

    # Materialize both boards
    @board1.materialize_storage
    @board2.materialize_storage

    board1_initial = @board1.bytes_used
    board2_initial = @board2.bytes_used

    # Small delay to ensure UUIDv7 timestamp advances for transfer entries
    travel 1.second

    @card.update!(board: @board2)

    # Materialize again
    @board1.materialize_storage
    @board2.materialize_storage

    # Board1 loses 1024, Board2 gains 1024
    assert_equal board1_initial - 1024, @board1.bytes_used
    assert_equal board2_initial + 1024, @board2.bytes_used
  end

  test "non-board updates do not trigger transfer tracking" do
    @card.image.attach io: StringIO.new("x" * 1024), filename: "test.png", content_type: "image/png"
    initial_count = Storage::Entry.where(operation: [ "transfer_out", "transfer_in" ]).count

    @card.update!(title: "New Title")

    final_count = Storage::Entry.where(operation: [ "transfer_out", "transfer_in" ]).count
    assert_equal initial_count, final_count
  end

  test "attachments_for_storage returns all direct attachments" do
    @card.image.attach io: StringIO.new("x" * 1024), filename: "test.png", content_type: "image/png"
    attachments = @card.send(:attachments_for_storage)

    assert_equal 1, attachments.count
    assert_equal @card.image.blob.byte_size, attachments.first.blob.byte_size
  end
end
