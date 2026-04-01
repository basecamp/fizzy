# frozen_string_literal: true

# Yabeda plugins provide runtime/process metrics that Sentry's
# request-based tracing can't capture. sentry-yabeda bridges
# these to Sentry as trace-connected metrics.
#
# Included plugins (no overlap with Sentry native tracing):
#   yabeda-puma-plugin   — thread pool utilization, backlog, worker count
#   yabeda-activejob     — enqueue counts, queue latency (Sentry traces execution, not enqueue/wait)
#   yabeda-gc            — GC pause time, heap stats
#   yabeda-gvl_metrics   — GVL wait, running, I/O wait time (Ruby 3.2+)
#   yabeda-activerecord  — connection pool stats (pool exhaustion invisible to Sentry tracing)
#   yabeda-http_requests — external HTTP call counts/duration (S3, web-push, net-http-persistent)
#
# NOT included (overlap with Sentry spans):
#   yabeda-rails         — request duration, db/view runtime (Sentry traces these natively)
#
# NOT included (OSS Fizzy has no ActionCable channels):
#   yabeda-actioncable   — needs ApplicationCable::Channel base class

# Install yabeda-activejob hooks (SaaS does this in the engine, OSS needs it here)
require "yabeda/activejob"
Yabeda::ActiveJob.install!
