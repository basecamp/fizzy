require "json"

# Records what every test did and where it ran, so that repeating the suite can tell a
# flaky test from a broken one -- and hand back enough to reproduce the flake.
#
# The position is the point. A test name alone says the run was red; what fixes an order
# dependency is knowing which tests preceded the failure on the same worker, and under
# which seed. With work stealing off that pair replays exactly. See bin/flaky.
#
# Off unless FLAKY_LOG names a directory, so an ordinary run pays nothing for it.
module FlakyRecorder
  # Parallel workers are forks, so a shared file would need locking to say anything true.
  # One file per process instead, stitched back together by whoever reads them.
  module Recording
    def run
      super.tap { |result| FlakyRecorder.record(result) }
    end
  end

  class << self
    def install(directory)
      @directory = directory
      @sequence = 0

      FileUtils.mkdir_p(directory)
      Minitest::Test.prepend(Recording)
    end

    def record(result)
      log.puts JSON.generate \
        "worker" => ActiveSupport::TestCase.parallel_worker_id || 0,
        "sequence" => (@sequence += 1),
        "test" => "#{result.klass}##{result.name}",
        "outcome" => outcome_of(result),
        "detail" => detail_of(result)
    end

    private
      # Opened lazily and re-opened when the pid changes, because a handle inherited across
      # fork would have every worker interleaving into one file.
      def log
        if @pid != Process.pid
          @pid = Process.pid
          @log = File.open(File.join(@directory, "#{Process.pid}.jsonl"), "a")
          @log.sync = true
        end

        @log
      end

      # A skip is neither a pass nor a failure, and counting it as either would have a
      # conditionally skipped test look flaky every night.
      def outcome_of(result)
        case
        when result.skipped? then "skip"
        when result.error?   then "error"
        when result.passed?  then "pass"
        else                      "fail"
        end
      end

      def detail_of(result)
        result.failures.first&.message&.lines&.first&.strip unless result.passed?
      end
  end
end
