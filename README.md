# Fizzy + Sentry Telemetry Demo

This fork of [Fizzy](https://fizzy.do/) (37signals' Kanban app) demonstrates a complete Sentry observability setup for a production Rails application.

## What this demonstrates

Three complementary telemetry layers, each handling what it does best with zero overlap:

| Layer | What it captures | How |
|-------|-----------------|-----|
| **Sentry native tracing** | Request spans, DB queries, view rendering, queue time | Automatic via `sentry-rails` |
| **Yabeda + sentry-yabeda** | Puma thread pool, GVL contention, GC pauses, job queue latency | Trace-connected aggregate metrics |
| **Sentry.metrics.\*** | Business events (cards created, moved, comments, notifications) | Direct API calls in model callbacks |

### Sentry metrics + Yabeda

Sentry supports custom metrics natively via `Sentry.metrics.*`. Yabeda is a vendor-neutral Ruby metrics framework with a rich plugin ecosystem — most plugins are built for Prometheus, exposing process-level runtime data like GC pressure, GVL contention, connection pool saturation, and thread pool utilization.

`sentry-yabeda` bridges the two: it registers a Yabeda adapter that routes any metric increment or gauge set to `Sentry.metrics`, making the entire Yabeda plugin ecosystem available in Sentry with no code changes to the plugins themselves. If you already have Yabeda plugins sending to Prometheus, you can send the same data to Sentry in parallel.

The key constraint: only use it for metrics that have no overlap with what Sentry traces natively. Request duration, DB query time, and view rendering are already captured as spans — adding them again as metrics is noise. The plugins included here cover only what tracing can't see: process-level runtime state.

### Yabeda plugins included

Only plugins that provide metrics Sentry can't capture natively:

| Plugin | Metrics | Why not native Sentry? |
|--------|---------|----------------------|
| [yabeda-puma-plugin](https://github.com/yabeda-rb/yabeda-puma-plugin) | Thread pool utilization, backlog, workers | Process-level, not request-scoped |
| [yabeda-activejob](https://github.com/Fullscript/yabeda-activejob) | Enqueue counts, queue latency | Sentry traces execution, not enqueue/wait |
| [yabeda-gc](https://github.com/ianks/yabeda-gc) | GC pause time, heap stats | Runtime metric, invisible to tracing |
| [yabeda-gvl_metrics](https://github.com/speedshop/yabeda-gvl_metrics) | GVL wait, running, I/O wait time | Core contention metric (Ruby 3.2+) |
| [yabeda-activerecord](https://github.com/yabeda-rb/yabeda-activerecord) | Connection pool size, busy/idle/waiting | Pool exhaustion invisible to tracing |
| [yabeda-http_requests](https://github.com/yabeda-rb/yabeda-http_requests) | External HTTP call counts and duration | Outbound calls (S3, web-push) not auto-traced |

Notably **excluded**: `yabeda-rails` (request duration, db/view runtime) overlaps with Sentry's native span instrumentation.

### Pull vs push: the periodic collector

Yabeda's gauge plugins register `collect` blocks designed for Prometheus's pull model -- a scrape request triggers `Yabeda.collect!`. Sentry is push-based, so there's no scrape trigger.

`sentry-yabeda` includes a **periodic collector** that calls `Yabeda.collect!` every 15 seconds on a background thread. This is started after Sentry init:

```ruby
# config/initializers/sentry.rb
require "sentry-yabeda"
Sentry::Yabeda.start_collector!
```

Without the collector, event-driven metrics (counters, histograms) still flow -- but runtime gauges (GC stats, GVL contention, Puma thread pool) won't. The Puma control app must also be enabled so `yabeda-puma-plugin` can fetch thread/backlog stats:

```ruby
# config/puma.rb
activate_control_app "unix://tmp/pumactl.sock", no_token: true
plugin :yabeda

on_worker_boot do
  Sentry::Yabeda.start_collector! if defined?(Sentry) && Sentry.initialized?
end
```

## Prerequisites

```bash
# System dependencies
brew bundle           # installs vips, sentry CLI

# Runtime (via mise)
mise install          # installs Ruby, Node
```

## Setup

```bash
git clone https://github.com/<your-fork>/fizzy.git
cd fizzy
echo "SENTRY_DSN=https://key@o0.ingest.sentry.io/0" > .env
bin/setup
bin/rails db:seed
```

## Running

**Terminal 1** -- Fizzy:
```bash
bin/dev
```

**Terminal 2** -- Generate traffic for dashboards:
```bash
bin/rails traffic:generate           # 20 rounds, 1s delay
ROUNDS=100 DELAY=0.5 bin/rails traffic:generate  # more data, faster
```

## Traffic generator

`bin/rails traffic:generate` drives all three telemetry layers and produces data visible in Sentry under **Performance** (transactions), **Metrics** (custom and runtime metrics), and **Errors** (if anything raises):

| What | Sentry data produced |
|------|---------------------|
| HTTP requests to 4 endpoints | Transactions with DB/view spans |
| `X-Request-Start` header | Queue time on each transaction |
| Card creation | `fizzy.cards_created` metric + `activerecord.*` query metrics |
| Comment creation | `fizzy.comments_created` metric |
| Card moves between columns | `fizzy.cards_moved` metric |
| Card closures (every 4th round) | Model callbacks, job enqueue metrics |
| Background collector (every 15s) | Puma, GC, GVL, connection pool gauge metrics |

Configure with environment variables: `ROUNDS` (default: 20), `DELAY` (default: 1.0s), `FIZZY_URL` (default: http://fizzy.localhost:3006), `FIZZY_USER` (default: dingsdax@sentry.io).

## Project structure (telemetry files)

```
config/initializers/
  sentry.rb                    # Sentry init, metrics enabled, collector started
  sentry_business_metrics.rb   # Direct Sentry.metrics.* calls on model callbacks
  yabeda.rb                    # Documents which Yabeda plugins are included and why
lib/tasks/
  traffic.rake                 # Traffic generator for dashboard demos
Brewfile                       # System deps (vips, sentry CLI)
.mise.toml                     # Runtime deps (Ruby, Node)
```

## Upstream

This is a fork of [basecamp/fizzy](https://github.com/basecamp/fizzy). See the upstream repo for Fizzy's own documentation, deployment guides, and contribution guidelines.
