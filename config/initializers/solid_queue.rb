SolidQueue.on_start do
  Process.warmup

  Yabeda::Prometheus::Exporter.start_metrics_server! unless ENV["BEAMER_TESTBED"].present?
end
