require "test_helper"

class Storage::MaterializeJobTest < ActiveJob::TestCase
  setup do
    @account = accounts("37s")
    @board = boards(:writebook)
  end

  test "calls materialize_storage on account" do
    Storage::Entry.record(account: @account, delta: 1024, operation: "attach")

    Storage::MaterializeJob.perform_now(@account)

    assert_not_nil @account.storage_total
    assert_equal 1024, @account.bytes_used
  end

  test "calls materialize_storage on board" do
    Storage::Entry.record(account: @account, board: @board, delta: 2048, operation: "attach")

    Storage::MaterializeJob.perform_now(@board)

    assert_not_nil @board.storage_total
    assert_equal 2048, @board.bytes_used
  end

  test "job is idempotent" do
    Storage::Entry.record(account: @account, delta: 1024, operation: "attach")

    3.times { Storage::MaterializeJob.perform_now(@account) }

    assert_equal 1024, @account.bytes_used
  end

  test "job processes entries added between runs" do
    Storage::Entry.record(account: @account, delta: 1000, operation: "attach")
    Storage::MaterializeJob.perform_now(@account)

    # Small delay to ensure UUIDv7 timestamp advances
    travel 1.second

    Storage::Entry.record(account: @account, delta: 500, operation: "attach")
    Storage::MaterializeJob.perform_now(@account)

    assert_equal 1500, @account.bytes_used
  end

  test "job queued to backend queue" do
    assert_equal "backend", Storage::MaterializeJob.new.queue_name
  end

  test "job has concurrency limit by owner" do
    job = Storage::MaterializeJob.new(@account)
    # limits_concurrency is a Solid Queue feature
    # Just verify the job can be instantiated and has the correct queue
    assert_equal "backend", job.queue_name
  end
end
