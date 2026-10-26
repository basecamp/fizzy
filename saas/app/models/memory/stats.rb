module Memory
  class Stats
    def initialize(logger)
      @logger = logger
    end

    # Read counters individually to avoid retaining a GC.stat hash across the job.
    def collect
      @before_rss                      = self.class.current_rss_bytes
      @before_heap_available_slots     = GC.stat(:heap_available_slots)
      @before_heap_live_slots          = GC.stat(:heap_live_slots)
      @before_total_allocated_objects  = GC.stat(:total_allocated_objects)
      @before_oldmalloc_increase_bytes = GC.stat(:oldmalloc_increase_bytes)
      @before_minor_gc_count           = GC.stat(:minor_gc_count)
      @before_major_gc_count           = GC.stat(:major_gc_count)
      @before_gc_time                  = GC.stat(:time)
      begin
        yield
      ensure
        log_all
      end
    end

    def log_all
      after_rss                      = self.class.current_rss_bytes
      after_heap_available_slots     = GC.stat(:heap_available_slots)
      after_heap_live_slots          = GC.stat(:heap_live_slots)
      after_total_allocated_objects  = GC.stat(:total_allocated_objects)
      after_oldmalloc_increase_bytes = GC.stat(:oldmalloc_increase_bytes)
      after_minor_gc_count           = GC.stat(:minor_gc_count)
      after_major_gc_count           = GC.stat(:major_gc_count)
      after_gc_time                  = GC.stat(:time)

      gc_delta = {}
      nonzero_delta(gc_delta, :heap_available_slots,     after_heap_available_slots,     @before_heap_available_slots)
      nonzero_delta(gc_delta, :heap_live_slots,           after_heap_live_slots,          @before_heap_live_slots)
      nonzero_delta(gc_delta, :total_allocated_objects,   after_total_allocated_objects,  @before_total_allocated_objects)
      nonzero_delta(gc_delta, :oldmalloc_increase_bytes, after_oldmalloc_increase_bytes, @before_oldmalloc_increase_bytes)
      nonzero_delta(gc_delta, :minor_gc_count,            after_minor_gc_count,           @before_minor_gc_count)
      nonzero_delta(gc_delta, :major_gc_count,            after_major_gc_count,           @before_major_gc_count)
      nonzero_delta(gc_delta, :time,                      after_gc_time,                  @before_gc_time)

      memory = { total: { rss_bytes: after_rss } }
      rss_delta = after_rss - @before_rss
      memory[:delta] = { rss_bytes: rss_delta } unless rss_delta == 0

      logger.struct \
        performance: {
          memory: memory,
          gc: {
            total: {
              heap_available_slots:     after_heap_available_slots,
              heap_live_slots:          after_heap_live_slots,
              total_allocated_objects:  after_total_allocated_objects,
              oldmalloc_increase_bytes: after_oldmalloc_increase_bytes,
              minor_gc_count:           after_minor_gc_count,
              major_gc_count:           after_major_gc_count,
              time:                     after_gc_time
            },
            **(gc_delta.any? ? { delta: gc_delta } : {}),
            last_major_by: GC.latest_gc_info(:major_by).to_s
          }
        }
    end

    def self.current_rss_bytes
      if kilobytes = File.read("/proc/self/status")[/^VmRSS:\s+(\d+)/, 1]
        kilobytes.to_i * 1024
      else
        0
      end
    rescue SystemCallError
      0
    end

    private
      attr_reader :logger

      def nonzero_delta(hash, key, after_val, before_val)
        delta = after_val - before_val
        hash[key] = delta unless delta == 0
      end
  end
end
