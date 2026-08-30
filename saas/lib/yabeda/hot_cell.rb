module Yabeda
  # Two namespace traps here fail silently: inside `module Yabeda`, `Rails` resolves to Yabeda::Rails, so
  # error reporting must say ::Rails; and `hotcell` is a DSL method that exists only inside
  # Yabeda.configure, so factored-out methods must say Yabeda.hotcell or they record nothing.
  module HotCell
    def self.install!
      Yabeda.configure do
        group :hotcell

        counter :requests, comment: "Calls through perform_in_hotcell, by outcome",
          tags: %i[ cell operation code cause ]
        histogram :perform, comment: "Time the cell spent performing", unit: :seconds,
          tags: %i[ cell operation ], buckets: [ 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 120 ]

        gauge :up, comment: "1 when the local cell answers its control socket",
          tags: %i[ cell ], aggregation: :most_recent
        gauge :running, comment: "Workers busy right now", tags: %i[ cell ], aggregation: :most_recent
        gauge :queued, comment: "Connections waiting for a worker", tags: %i[ cell ], aggregation: :most_recent
        gauge :queue_high_water, comment: "Deepest the queue has been since boot",
          tags: %i[ cell ], aggregation: :most_recent
        gauge :cancelled, comment: "Callers that gave up before the cell answered (a floor)",
          tags: %i[ cell ], aggregation: :most_recent
        gauge :killed, comment: "Workers killed since boot, by cause",
          tags: %i[ cell cause ], aggregation: :most_recent
        gauge :uptime_seconds, comment: "Seconds since the supervisor booted",
          tags: %i[ cell ], aggregation: :most_recent

        collect { Yabeda::HotCell.collect_stats }
      end

      subscribe_to_performs
    end

    def self.collect_stats
      ::HotCell.cells.each_value do |cell|
        next unless cell.enabled?

        response = cell.metrics
        Yabeda.hotcell.up.set({ cell: cell.name }, response&.ok? ? 1 : 0)
        next unless response&.ok?

        set_counters cell, response.result
      end
    rescue => error
      # A scrape must not fail because a cell is misbehaving.
      ::Rails.error.report error, handled: true
    end

    # The subscriber raises into whoever called instrument, so an unguarded bug here would arrive as a
    # failed conversion rather than as missing metrics.
    def self.subscribe_to_performs
      ActiveSupport::Notifications.subscribe "perform.hot_cell" do |event|
        record_perform event
      rescue => error
        ::Rails.error.report error, handled: true
      end
    end

    # Deliberately no Sentry report from here: the raise the caller sees already reaches Sentry, so a
    # report here was a second copy under a second name.
    def self.record_perform(event)
      labels = { cell: event.payload[:cell], operation: event.payload[:operation] }
      code = event.payload[:code]

      # cause is empty rather than absent: a sometimes-missing label is a separate Prometheus series.
      Yabeda.hotcell.requests.increment(labels.merge(code: code || "ok", cause: event.payload[:cause].to_s))
      Yabeda.hotcell.perform.measure(labels, (event.payload[:perform_ms] || 0) / 1000.0)
      log_perform event, labels, code
    end

    # The line carries two clocks on purpose: `perform_ms` is what the cell measured, `duration_ms` is
    # what this process waited, and their difference is the queue and the socket. `Rails.logger.info`
    # rather than `logger.struct`, because `struct` lives on the per-request proxy and a subscriber
    # has none.
    private_class_method def self.log_perform(event, labels, code)
      duration_ms = event.duration.round(1)

      ::Rails.logger.info "  HotCell (#{duration_ms}ms) " + labels.merge(
        code: code || "ok",
        cause: event.payload[:cause],
        perform_ms: event.payload[:perform_ms],
        duration_ms: duration_ms,
        bytes_in: event.payload[:bytes_in],
        bytes_out: event.payload[:bytes_out]).to_json
    end

    private_class_method def self.set_counters(cell, counters)
      tags = { cell: cell.name }

      Yabeda.hotcell.running.set(tags, counters[:running])
      Yabeda.hotcell.queued.set(tags, counters[:queued])
      Yabeda.hotcell.queue_high_water.set(tags, counters[:queue_high_water])
      Yabeda.hotcell.cancelled.set(tags, counters[:cancelled])
      Yabeda.hotcell.uptime_seconds.set(tags, counters[:uptime_s])
      counters[:killed_by].each { |cause, count| Yabeda.hotcell.killed.set(tags.merge(cause: cause), count) }
    end
  end
end
