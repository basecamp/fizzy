require "test_helper"
require "yabeda/testing"

class HotcellTelemetryTest < ActiveSupport::TestCase
  OPERATION = "active_storage.transformers.image.vips"

  setup do
    Yabeda::TestAdapter.instance.reset!
    @log = ActiveSupport::Logger.new(@output = StringIO.new)
    Rails.logger.broadcast_to @log
  end

  teardown { Rails.logger.stop_broadcasting_to @log }

  test "a call writes one log line" do
    perform

    assert_equal 1, @output.string.scan(/^  HotCell \(/).size
  end

  test "a call is counted by outcome" do
    perform

    labels = { cell: Fizzy::Saas::Cell::NAME, operation: OPERATION, code: "ok", cause: "" }
    assert_equal 1, Yabeda::TestAdapter.instance.counters[Yabeda.hotcell.requests][labels]
  end

  private
    def perform
      ActiveSupport::Notifications.instrument "perform.hot_cell",
        cell: Fizzy::Saas::Cell::NAME, operation: OPERATION, perform_ms: 250
    end
end
