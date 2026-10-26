require "test_helper"

# The wire budget and deadline arithmetic, against a scripted io: no sockets.
class Oauth::ClientMetadata::BudgetedIoTest < ActiveSupport::TestCase
  class ScriptedIo
    def initialize(events)
      @events = events
    end

    def read_nonblock(size, buf = nil, exception: true)
      event = @events.shift

      if event.is_a?(String)
        chunk = event.byteslice(0, size)
        leftover = event.byteslice(chunk.bytesize..)
        @events.unshift(leftover) if leftover.present?
        buf ? buf.replace(chunk) : chunk
      end
    end

    def to_io
      self
    end

    def wait_readable(timeout)
      true
    end
  end

  test "the stdlib seams the wrapper relies on still exist" do
    assert Net::HTTP.private_method_defined?(:on_connect)
    assert Net::BufferedIO.private_method_defined?(:rbuf_fill)
  end

  test "reading past the wire budget fails" do
    io = budgeted(ScriptedIo.new([ "x" * 100, "x" ]), wire_budget: 100)

    assert_raises Oauth::ClientMetadata::Fetcher::WireBudgetExceeded do
      io.readuntil("\n")
    end
  end

  test "reading within the wire budget succeeds" do
    io = budgeted(ScriptedIo.new([ "HTTP/1.1 200 OK\r\n" ]), wire_budget: 100)

    assert_equal "HTTP/1.1 200 OK\r\n", io.readuntil("\n")
  end

  test "a passed deadline fails before reading" do
    io = budgeted(ScriptedIo.new([ "x" ]), wire_budget: 100, deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) - 1)

    assert_raises Oauth::ClientMetadata::Fetcher::DeadlineExceeded do
      io.readuntil("\n")
    end
  end

  private
    def budgeted(io, wire_budget:, deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5)
      Oauth::ClientMetadata::Fetcher::BudgetedIO.new(io, deadline: deadline, wire_budget: wire_budget)
    end
end
