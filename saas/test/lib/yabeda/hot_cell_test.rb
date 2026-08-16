require "test_helper"
require "yabeda/testing"

# Asserting values rather than that the block ran, because both of this file's namespace traps are silent:
# a bare `Rails` raises inside the rescue, and a bare `hotcell` records nothing. assert_nothing_raised
# would pass against either.
class Yabeda::HotCellTest < ActiveSupport::TestCase
  COUNTERS = { uptime_s: 41, running: 2, queued: 3, queue_high_water: 7, cancelled: 1,
               requests: {}, killed_by: { memory: 5, deadline: 2 } }

  setup do
    Yabeda::TestAdapter.instance.reset!
    @log = StringIO.new
    Rails.logger.broadcast_to ActiveSupport::Logger.new(@log)
  end

  teardown { Fizzy::Saas::Cell.register! }

  test "publishes the cell's counters" do
    stub_cell_metrics COUNTERS

    Yabeda::HotCell.collect_stats

    assert_equal 1, gauge(:up)
    assert_equal 2, gauge(:running)
    assert_equal 3, gauge(:queued)
    assert_equal 7, gauge(:queue_high_water)
    assert_equal 1, gauge(:cancelled)
    assert_equal 41, gauge(:uptime_seconds)
  end

  test "publishes kills by cause" do
    stub_cell_metrics COUNTERS

    Yabeda::HotCell.collect_stats

    assert_equal 5, gauge(:killed, cause: :memory)
    assert_equal 2, gauge(:killed, cause: :deadline)
  end

  test "a cell that does not answer is down rather than missing" do
    cell = registered_cell
    cell.stubs(:enabled?).returns(true)
    cell.stubs(:metrics).returns(nil)

    Yabeda::HotCell.collect_stats

    assert_equal 0, gauge(:up)
    assert_nil gauge(:running)
  end

  test "an unregistered cell publishes nothing rather than raising" do
    registered_cell.stubs(:enabled?).returns(false)

    Yabeda::HotCell.collect_stats

    assert_nil gauge(:up)
  end

  test "a scrape does not fail because a cell is misbehaving" do
    registered_cell.stubs(:enabled?).raises(StandardError.new("boom"))

    assert_nothing_raised { Yabeda::HotCell.collect_stats }
  end

  test "counts a successful call as ok and measures what the cell spent" do
    Yabeda::HotCell.record_perform perform_event(perform_ms: 250)

    assert_equal 1, counter(:requests, code: "ok")
    assert_equal 0.25, histogram(:perform_seconds)
  end

  test "counts a failure under its own code" do
    Yabeda::HotCell.record_perform perform_event(code: "capacity")

    assert_equal 1, counter(:requests, code: "capacity")
  end

  # The histogram says how long transforms take on a host; it cannot say what one upload paid. That is
  # what a request's own log line is for, and it must carry both the cell's time and the caller's, because
  # their difference is the queue and the socket — the number that says whether the cell or the plumbing
  # was slow.
  test "logs what each call cost" do
    Yabeda::HotCell.record_perform perform_event(perform_ms: 250, duration_ms: 310, bytes_in: 4096, bytes_out: 512)

    assert_equal "active_storage.transformers.image.vips", logged["operation"]
    assert_equal "ok", logged["code"]
    assert_equal 250, logged["perform_ms"]
    assert_equal 310, logged["duration_ms"]
    assert_equal 4096, logged["bytes_in"]
    assert_equal 512, logged["bytes_out"]
  end

  test "logs a failure under its own code" do
    Yabeda::HotCell.record_perform perform_event(code: "capacity")

    assert_equal "capacity", logged["code"]
  end

  test "reports a permanent failure as information about one file" do
    Rails.error.expects(:report).with { |error, options| error.is_a?(Fizzy::Saas::Cell::UnprocessableAttachment) &&
      options[:severity] == :info }

    Yabeda::HotCell.record_perform perform_event(code: "unreadable")
  end

  test "reports a transient failure as a warning about the cell" do
    Rails.error.expects(:report).with { |error, options| error.is_a?(Fizzy::Saas::Cell::ProcessingUnavailable) &&
      options[:severity] == :warning }

    Yabeda::HotCell.record_perform perform_event(code: "capacity")
  end

  test "a code from a newer cell is a warning rather than an ArgumentError" do
    Rails.error.expects(:report).with { |error, options| options[:severity] == :warning }

    Yabeda::HotCell.record_perform perform_event(code: "invented_by_a_later_deploy")
  end

  test "a metrics bug arrives as missing metrics rather than as a failed conversion" do
    Yabeda.stubs(:hotcell).raises(StandardError.new("boom"))

    assert_nothing_raised do
      ActiveSupport::Notifications.instrument("perform.hot_cell") { }
    end
  end

  private
    def registered_cell
      HotCell.cell Fizzy::Saas::Cell::NAME
    end

    def stub_cell_metrics(counters)
      cell = registered_cell
      cell.stubs(:enabled?).returns(true)
      cell.stubs(:metrics).returns(stub(ok?: true, result: counters))
    end

    # `duration_ms` is what the caller waited, which the event measures itself; the payload only carries
    # what the cell reported. Faking it takes the same start/finish the real event has.
    def perform_event(code: nil, perform_ms: 0, cause: nil, duration_ms: 0, bytes_in: nil, bytes_out: nil)
      start = Time.now
      ActiveSupport::Notifications::Event.new("perform.hot_cell", start, start + duration_ms / 1000.0, nil,
        { cell: Fizzy::Saas::Cell::NAME, operation: "active_storage.transformers.image.vips",
          code: code, cause: cause, perform_ms: perform_ms, bytes_in: bytes_in, bytes_out: bytes_out })
    end

    def logged
      JSON.parse @log.string[/^hotcell (\{.*\})$/, 1]
    end

    def gauge(metric, **tags)
      Yabeda::TestAdapter.instance.gauges[Yabeda.hotcell.public_send(metric)][tags.merge(cell: Fizzy::Saas::Cell::NAME)]
    end

    def counter(metric, **tags)
      Yabeda::TestAdapter.instance.counters[Yabeda.hotcell.public_send(metric)][default_labels.merge(tags)]
    end

    def histogram(metric)
      Yabeda::TestAdapter.instance.histograms[Yabeda.hotcell.public_send(metric)][default_labels]
    end

    def default_labels
      { cell: Fizzy::Saas::Cell::NAME, operation: "active_storage.transformers.image.vips" }
    end
end
