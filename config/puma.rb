# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# You can control the number of workers using ENV["WEB_CONCURRENCY"]. You
# should only set this value when you want to run 2 or more workers. The
# default is already 1.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Run Solid Queue with Puma
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

# Expose Prometheus metrics at http://0.0.0.0:9394/metrics.
# In dev, overridden to http://127.0.0.1:9306/metrics in .mise.toml.
control_uri = Rails.env.local? ? "unix://tmp/pumactl.sock" : "auto"
activate_control_app control_uri, no_token: true
plugin :yabeda
plugin :yabeda_prometheus
