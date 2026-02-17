module Yabeda
  module GVL
    WAIT_HISTOGRAM_BUCKETS = [ 0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10 ]

    def self.install!
      GVLTools::GlobalTimer.enable
      GVLTools::WaitingThreads.enable

      Yabeda.configure do
        group :gvl do
          gauge :waiting_threads,
            comment: "Number of threads currently waiting to acquire the GVL"

          gauge :global_timer_total_seconds,
            comment: "Total time all threads spent waiting on the GVL (seconds)"

          histogram :request_wait,
            unit: :seconds,
            comment: "GVL wait time experienced during a single request (seconds)",
            buckets: WAIT_HISTOGRAM_BUCKETS
        end

        collect do
          gvl.waiting_threads.set({}, GVLTools::WaitingThreads.count)
          gvl.global_timer_total_seconds.set({}, GVLTools::GlobalTimer.monotonic_time / 1_000_000_000.0)
        end
      end
    end
  end
end
