module Yabeda
  # A cell's control socket is host-local, so only a process on the same host can reach it. The collect
  # block runs in every scraped process on every host, which matches the topology exactly.
  #
  # Two namespace traps live in this file, and both fail silently. Inside `module Yabeda`, `Rails` resolves
  # to Yabeda::Rails, so error reporting has to say ::Rails or it raises inside the rescue that was meant
  # to swallow it. And `hotcell` is a DSL method that exists only inside Yabeda.configure, so a method
  # factored out of the collect block has to say Yabeda.hotcell or it records nothing at all. The tests
  # assert gauge values for that reason: asserting the block ran would pass against both.
  module HotCell
    def self.install!
      Yabeda.configure do
        group :hotcell

        counter :requests, comment: "Calls through perform_in_hotcell, by outcome",
          tags: %i[ cell operation code ]
        histogram :perform_seconds, comment: "Time the cell spent performing", unit: :seconds,
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

    # Deliberately no Sentry report from here. The client raises the cell's verdict as the registered
    # permanent or transient class, and that raise reaches Sentry with the right class wherever nothing
    # rescues it; where something rescues it to keep a save from failing, that rescue reports. A report
    # from this subscriber as well was a second copy of the same event under a second name.
    def self.record_perform(event)
      labels = { cell: event.payload[:cell], operation: event.payload[:operation] }
      code = event.payload[:code]

      Yabeda.hotcell.requests.increment(labels.merge(code: code || "ok"))
      Yabeda.hotcell.perform_seconds.measure(labels, (event.payload[:perform_ms] || 0) / 1000.0)
      log_perform event, labels, code
    end

    # One line per call, so an upload that ran a conversion inline shows what it paid. The histogram cannot
    # say that: it knows how long transforms take on a host, not which request waited for one. Two clocks
    # on purpose — `perform_ms` is what the cell measured inside the worker, `duration_ms` is what this
    # process waited — because their difference is the queue and the socket, which is the number that says
    # whether the cell or the plumbing was slow.
    #
    # `Rails.logger.info` rather than `logger.struct`, because `struct` is a method on the per-request
    # proxy a controller or job holds, and a notification subscriber has neither. Structured logging still
    # gathers every line written during a request onto that request's record, so this lands beside the
    # request's own duration.
    private_class_method def self.log_perform(event, labels, code)
      ::Rails.logger.info "hotcell " + labels.merge(
        code: code || "ok",
        cause: event.payload[:cause],
        perform_ms: event.payload[:perform_ms],
        duration_ms: event.duration.round(1),
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
