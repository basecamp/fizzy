# frozen_string_literal: true

# Yabeda plugins provide runtime/process metrics that Sentry's
# request-based tracing can't capture. sentry-yabeda bridges
# these to Sentry as trace-connected metrics.
#
# Included plugins:
#   yabeda-puma-plugin   — thread pool utilization, backlog, worker count
#   yabeda-gc            — GC pause time, heap stats
#   yabeda-activerecord  — connection pool stats (pool exhaustion invisible to Sentry tracing)
