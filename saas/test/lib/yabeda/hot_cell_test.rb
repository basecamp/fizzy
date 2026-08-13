require "test_helper"
require "yabeda/testing"

# Asserting values rather than that the block ran, because both of this file's namespace traps are silent:
# a bare `Rails` raises inside the rescue, and a bare `hotcell` records nothing. assert_nothing_raised
# would pass against either.
class Yabeda::HotCellTest < ActiveSupport::TestCase
  COUNTERS = { uptime_s: 41, running: 2, queued: 3, queue_high_water: 7, cancelled: 1,
               requests: {}, killed_by: { memory: 5, deadline: 2 } }

  setup { Yabeda::TestAdapter.instance.reset! }

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

    def perform_event(code: nil, perform_ms: 0, cause: nil)
      ActiveSupport::Notifications::Event.new("perform.hot_cell", nil, nil, nil,
        { cell: Fizzy::Saas::Cell::NAME, operation: "active_storage.transformers.image.vips",
          code: code, cause: cause, perform_ms: perform_ms })
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
