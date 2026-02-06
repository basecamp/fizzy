# Enable autotuner. Alternatively, call Autotuner.sample_ratio= with a value
# between 0 and 1.0 to sample on a portion of instances.
Autotuner.enabled = true

# This callback is called whenever a suggestion is provided by this gem.
# Log to structured logging for query/analysis in Loki. This is called
# once per autotuner heuristic.
Autotuner.reporter = proc do |heuristic_report|
  report = heuristic_report.to_s

  Rails.logger.info "GCAUTOTUNE: #{report}"

  RailsStructuredLogging.instrument_script "autotuner" do
    Rails.logger.info report.to_s
  end if defined? RailsStructuredLogging
end
