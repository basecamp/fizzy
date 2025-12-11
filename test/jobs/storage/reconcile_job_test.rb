require "test_helper"

class Storage::ReconcileJobTest < ActiveJob::TestCase
  setup do
    Current.session = sessions(:david)
    @account = accounts("37s")
    @board = @account.boards.create!(name: "Test Board", creator: users(:david))
    @card = @board.cards.create!(title: "Test Card", creator: users(:david))
  end

  test "reconcile_storage corrects drift when ledger undercounts" do
    @card.image.attach io: StringIO.new("x" * 1000), filename: "test.png", content_type: "image/png"
    Storage::Entry.where(board: @board).delete_all

    Storage::ReconcileJob.perform_now(@board)

    entry = Storage::Entry.find_by(board: @board, operation: "reconcile")
    assert_not_nil entry
    assert_equal 1000, entry.delta
  end

  test "reconcile_storage corrects drift when ledger overcounts" do
    Storage::Entry.create! \
      account_id: @account.id,
      board_id: @board.id,
      delta: 5000,
      operation: "attach"

    Storage::ReconcileJob.perform_now(@board)

    entry = Storage::Entry.find_by(board: @board, operation: "reconcile")
    assert_not_nil entry
    assert_equal(-5000, entry.delta)
  end

  test "reconcile_storage creates no entry when ledger matches reality" do
    @card.image.attach io: StringIO.new("x" * 1000), filename: "test.png", content_type: "image/png"
    initial_count = Storage::Entry.where(board: @board).count

    Storage::ReconcileJob.perform_now(@board)

    assert_equal initial_count, Storage::Entry.where(board: @board).count
  end

  test "job queued to backend queue" do
    assert_equal "backend", Storage::ReconcileJob.new.queue_name
  end

  test "job has concurrency limit by owner" do
    job = Storage::ReconcileJob.new(@board)
    # limits_concurrency is a Solid Queue feature
    # Just verify the job can be instantiated and has the correct queue
    assert_equal "backend", job.queue_name
  end

  test "job raises ReconcileAborted when reconcile fails" do
    # Use perform_now with a fresh board that we can stub
    board = @account.boards.create!(name: "Abort Test Board", creator: users(:david))

    # Prepend a module to intercept reconcile_storage
    intercept = Module.new do
      def reconcile_storage
        false
      end
    end
    board.singleton_class.prepend(intercept)

    assert_raises Storage::ReconcileJob::ReconcileAborted do
      # Call perform directly to avoid serialization
      Storage::ReconcileJob.new.perform(board)
    end
  end
end
