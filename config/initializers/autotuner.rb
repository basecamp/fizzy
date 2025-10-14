# Enable autotuner. Alternatively, call Autotuner.sample_ratio= with a value
# between 0 and 1.0 to sample on a portion of instances.
Autotuner.enabled = true

# This callback is called whenever a suggestion is provided by this gem.
# You can output this report to your logging pipeline, stdout, a file,
# or somewhere else!
Autotuner.reporter = proc do |report|
  Rails.logger.info "GCAUTOTUNE: #{report}"
  Sentry.capture_message "Autotuner suggestion", level: :info, extra: { report: report.to_s }
end

# # This (optional) callback is called to provide metrics that can give you
# # insights about the performance of your app. It's recommended to send this
# # data to your observability service (e.g. Datadog, Prometheus, New Relic, etc).
# # Use a metric type that would allow you to calculate the average and percentiles.
# # On Datadog this would be the distribution type. On Prometheus this would be
# # the histogram type.
# Autotuner.metrics_reporter = proc do |metrics|
#   # stats is a hash of metric name (string) to integer value.
#   metrics.each do |key, val|
#     StatsD.gauge(key, val)
#   end
# end
