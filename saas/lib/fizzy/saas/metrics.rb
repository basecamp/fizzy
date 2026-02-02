Yabeda.configure do
  SHORT_HISTOGRAM_BUCKETS = [ 0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5 ]

  group :fizzy do
    counter :replica_stale,
      comment: "Number of requests served from a stale replica"

    histogram :replica_wait,
      unit: :seconds,
      comment: "Time spent waiting for replica to catch up with transaction",
      buckets: SHORT_HISTOGRAM_BUCKETS
  end
end
