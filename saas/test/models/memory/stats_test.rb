require "test_helper"

class Memory::StatsTest < ActiveSupport::TestCase
  test "records memory and GC totals and deltas using structured logging" do
    payload = {}
    logger = RailsStructuredLogging::Proxy.new(logger: Logger.new(nil), payload: payload)
    Memory::Stats.stubs(:current_rss_bytes).returns(1024, 2048)
    GC.expects(:start).never

    result = Memory::Stats.new(logger).collect { "finished" }

    assert_equal "finished", result
    assert_equal 2048, payload.dig(:performance, :memory, :total, :rss_bytes)
    assert_equal 1024, payload.dig(:performance, :memory, :delta, :rss_bytes)
    assert_kind_of Integer, payload.dig(:performance, :gc, :total, :major_gc_count)
    assert_kind_of String, payload.dig(:performance, :gc, :last_major_by)
  end

  test "records failed jobs and preserves their exception" do
    payload = {}
    logger = RailsStructuredLogging::Proxy.new(logger: Logger.new(nil), payload: payload)

    error = assert_raises(RuntimeError) do
      Memory::Stats.new(logger).collect { raise "job failed" }
    end

    assert_equal "job failed", error.message
    assert_kind_of Integer, payload.dig(:performance, :gc, :total, :major_gc_count)
  end

  test "reads resident memory in bytes" do
    File.expects(:read).with("/proc/self/status").returns("Name:\truby\nVmRSS:\t1234 kB\n")

    assert_equal 1234 * 1024, Memory::Stats.current_rss_bytes
  end

  test "unavailable process status does not prevent a job from running" do
    File.expects(:read).with("/proc/self/status").raises(Errno::ENOENT)

    assert_equal 0, Memory::Stats.current_rss_bytes
  end
end
