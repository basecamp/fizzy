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

    def self.record_perform(event)
      labels = { cell: event.payload[:cell], operation: event.payload[:operation] }
      code = event.payload[:code]

      Yabeda.hotcell.requests.increment(labels.merge(code: code || "ok"))
      Yabeda.hotcell.perform_seconds.measure(labels, (event.payload[:perform_ms] || 0) / 1000.0)
      report_failure event, labels, code if code
    end

    # A permanent code is a verdict about one file, which is information rather than an incident.
    # Everything else says the cell is having a bad day, and that is worth watching a trend for. The
    # classes are the registered cell's own, so Sentry groups these the same way it groups the exception
    # the caller actually saw.
    private_class_method def self.report_failure(event, labels, code)
      return unless ::HotCell.cell?(labels[:cell])

      cell = ::HotCell.cell(labels[:cell])
      permanent = permanent?(code, event.payload[:cause])
      error = (permanent ? cell.permanent : cell.transient).new("#{labels[:operation]}: #{code}")

      ::Rails.error.report error, handled: true, severity: permanent ? :info : :warning,
        context: labels.merge(code: code, cause: event.payload[:cause])
    end

    # Codes.permanent? raises ArgumentError on a code it has never heard of, which is exactly what a
    # deploy skew produces — so ask whether it knows the code first, and treat an unknown one the way the
    # taxonomy treats everything uncertain.
    private_class_method def self.permanent?(code, cause)
      ::HotCell::Codes.known?(code) && ::HotCell::Codes.permanent?(code, cause: cause)
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
