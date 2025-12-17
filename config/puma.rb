# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Run Solid Queue with Puma by default.
# Disabled when running fizzy-saas or via SOLID_QUEUE_IN_PUMA=false.
unless Fizzy.saas? || ENV["SOLID_QUEUE_IN_PUMA"] == "false"
  plugin :solid_queue
end

# Expose Prometheus metrics at http://0.0.0.0:9394/metrics (SaaS only).
# In dev, overridden to http://127.0.0.1:9306/metrics in .mise.toml.
if Fizzy.saas?
  control_uri = Rails.env.local? ? "unix://tmp/pumactl.sock" : "auto"
  activate_control_app control_uri, no_token: true
  plugin :yabeda
  plugin :yabeda_prometheus
end

if !Rails.env.local?
  # Because we expect fewer I/O waits than Rails apps that connect to the
  # database over the network, let's start with a baseline config of 1
  # worker per CPU, 1 thread per worker and tune it from there.
  #
  # https://edgeguides.rubyonrails.org/tuning_performance_for_deployment.html#puma
  workers Integer(ENV.fetch("WEB_CONCURRENCY") { Concurrent.physical_processor_count })
  threads 1, 1

  # Tell the Ruby VM that we're finished booting up.
  #
  # Now's the time to tidy the heap (GC, compact, free empty, malloc_trim, etc)
  # for optimal copy-on-write efficiency.
  before_fork do
    Process.warmup
  end

  # Defer major GC (full marking phase) until after request handling,
  # and perform major GC deferred during request handling.
  before_worker_boot do
    GC.config(rgengc_allow_full_mark: false)
  end

  out_of_band do
    GC.start if GC.latest_gc_info(:need_major_by)
  end
end
