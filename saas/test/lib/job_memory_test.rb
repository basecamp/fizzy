require "test_helper"

class Fizzy::Saas::JobMemoryTest < ActiveSupport::TestCase
  class MemoryTestJob < ActiveJob::Base
    def perform
      "finished"
    end
  end

  setup do
    @previous_log_job_memory = ENV["LOG_JOB_MEMORY"]
  end

  teardown do
    ENV["LOG_JOB_MEMORY"] = @previous_log_job_memory
  end

  test "memory diagnostics are opt in" do
    ENV.delete("LOG_JOB_MEMORY")
    Memory::Stats.expects(:new).never

    assert_equal "finished", MemoryTestJob.perform_now
  end

  test "enabled diagnostics attach memory and GC totals to the structured job event" do
    ENV["LOG_JOB_MEMORY"] = "true"
    job = MemoryTestJob.new

    assert_equal "finished", job.perform_now
    assert_kind_of Integer, job.structured_logs[:performance][:gc][:total][:major_gc_count]
    assert_kind_of Integer, job.structured_logs[:performance][:memory][:total][:rss_bytes]
  end
end
