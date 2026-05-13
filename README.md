# Fizzy + Sentry Telemetry Demo

This fork of [Fizzy](https://fizzy.do/) (37signals' Kanban app) demonstrates a complete Sentry observability setup for a production Rails application.

## What this demonstrates

Three complementary telemetry layers, each handling what it does best:

| Layer | What it captures | How |
|-------|-----------------|-----|
| **Sentry native tracing** | Request spans, DB queries, view rendering, queue time | Automatic via `sentry-rails` |
| **Yabeda + sentry-yabeda** | Request aggregates, Puma threads, GC pauses, connection pool | Yabeda plugins bridged to Sentry metrics |
| **Sentry.metrics.\*** | Business events (cards created, moved, comments, notifications) | Direct API calls in model callbacks |

### Sentry metrics + Yabeda

Sentry captures request-scoped telemetry well — traces, spans, errors — but it has no visibility into process-level runtime state: how many Puma threads are busy, whether the connection pool is saturated, or how much time the GC is stealing. That data lives in the Ruby VM and server internals, and you typically need a Prometheus-style setup to surface it.

[Yabeda](https://github.com/yabeda-rb/yabeda) is a vendor-neutral Ruby metrics framework whose plugin ecosystem already instruments these internals. `sentry-yabeda` bridges the two: it registers a Yabeda adapter that routes every counter increment, gauge set, and histogram observation to `Sentry.metrics.*`, making the entire Yabeda plugin ecosystem available in Sentry dashboards with no code changes to the plugins themselves.

The result: Sentry traces show you what happened in each request, Yabeda metrics show you what was happening in the process *while* that request ran, and direct `Sentry.metrics.*` calls capture business-level events. All three land in the same Sentry dashboard.

### Yabeda plugins included

| Plugin | Metrics | Overlap with Sentry tracing? |
|--------|---------|------------------------------|
| [yabeda-rails](https://github.com/yabeda-rb/yabeda-rails) | Request count, duration, view/DB runtime (aggregate distributions) | Yes — Sentry traces individual requests, yabeda-rails provides aggregate percentiles (p50/p95/p99) across all requests. Complementary views of the same data. |
| [yabeda-puma-plugin](https://github.com/yabeda-rb/yabeda-puma-plugin) | Thread pool utilization, backlog, workers | No — process-level, not request-scoped |
| [yabeda-gc](https://github.com/ianks/yabeda-gc) | GC pause time, heap stats | No — runtime metric, invisible to tracing |
| [yabeda-activerecord](https://github.com/yabeda-rb/yabeda-activerecord) | Connection pool size, busy/idle/waiting | No — pool exhaustion invisible to tracing |

Notably **excluded**: `yabeda-http_requests` (its Sniffer integration intercepts Sentry's own ingest HTTP call, causing a recursive mutex deadlock in the metric buffer flush cycle), `yabeda-activejob` (Sentry traces job execution natively via `sentry-rails`), `yabeda-actioncable` (most metrics require active WebSocket clients or special PubSub measurement setup), `yabeda-gvl_metrics` (needs sustained concurrent load to produce meaningful data).

### Unit normalization

Yabeda plugins declare metric units as plural Ruby symbols (`:seconds`, `:milliseconds`). Sentry's canonical unit format is singular (`second`, `millisecond`, `byte`). `sentry-yabeda` normalizes these automatically before emission, so dashboard queries must use the singular form — `distribution,second` not `distribution,seconds`.

### Pull vs push: the periodic collector

Yabeda's gauge plugins register `collect` blocks designed for Prometheus's pull model — a scrape request triggers `Yabeda.collect!`. Sentry is push-based, so there's no scrape trigger.

`sentry-yabeda` includes a **periodic collector** that calls `Yabeda.collect!` every 15 seconds on a background thread, started automatically when `enable_metrics` is true. Event-driven metrics (counters, histograms) flow immediately — runtime gauges (GC stats, Puma thread pool) require the collector.

The Puma control app must be enabled so `yabeda-puma-plugin` can fetch thread/backlog stats:

```ruby
# config/puma.rb
activate_control_app "unix://tmp/pumactl.sock", no_token: true
plugin :yabeda
```

## Prerequisites

```bash
# System dependencies
brew bundle           # installs vips, sentry CLI

# Runtime (via mise)
mise install          # installs Ruby
```

## Setup

```bash
git clone https://github.com/dingsdax/fizzy.git
cd fizzy
git checkout feat/sentry-yabeda-observability
echo "SENTRY_DSN=https://key@o0.ingest.sentry.io/0" > .env
bin/setup
bin/rails db:seed
```

## Running

**Terminal 1** — Fizzy:
```bash
bin/dev
```

**Terminal 2** — Generate traffic for dashboards:
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
| Card creation | `fizzy.cards_created` counter + `rails.requests_total` counter |
| Comment creation | `fizzy.comments_created` counter |
| Card moves between columns | `fizzy.cards_moved` counter + ActionCable broadcasts |
| Card closures (deferred 2–8 rounds) | `fizzy.card_lifetime_seconds` distribution |
| Background collector (every 15s) | Puma, GC, connection pool gauge metrics |

Configure with environment variables: `ROUNDS` (default: 20), `DELAY` (default: 1.0s), `FIZZY_URL` (default: http://fizzy.localhost:3006), `FIZZY_USER` (default: dingsdax@sentry.io).

## Soak test

`bin/rails soak:test` runs sustained traffic while monitoring Puma's thread count and RSS memory to detect leaks:

```bash
bin/dev                                           # Terminal 1
bin/rails soak:test                               # Terminal 2 (500 rounds, ~3 min)
ROUNDS=2000 DELAY=0.1 bin/rails soak:test         # longer run
```

The task samples process stats every N rounds and prints a summary table:

```
Round   Elapsed   RSS (MB)    Threads     Errors    Status
0       0.0s      187         18          0         baseline
25      28.9s     334         22          0         RSS +147MB, Threads +4
50      61.6s     385         24          0         RSS +51MB, Threads +2
...
```

Thread count should stabilize after warmup (~25 rounds). RSS growth in development mode is normal (no class caching, SQLite buffer growth); in production mode it should flatten after warmup.

Configure with: `ROUNDS` (default: 500), `DELAY` (default: 0.3s), `SAMPLE_EVERY` (default: 10).

## Dashboard setup

See [docs/sentry-dashboard.md](docs/sentry-dashboard.md) for CLI commands to create all Sentry dashboard widgets.

## Project structure (telemetry files)

```
config/initializers/
  sentry.rb                    # Sentry init, metrics + logs enabled
  sentry_business_metrics.rb   # Direct Sentry.metrics.* calls on model callbacks
lib/tasks/
  traffic.rake                 # Traffic generator for dashboard demos
  soak.rake                    # Soak test for thread/memory leak detection
Brewfile                       # System deps (vips, sentry CLI)
.mise.toml                     # Runtime deps (Ruby)
```

## Upstream

This is a fork of [basecamp/fizzy](https://github.com/basecamp/fizzy). See the upstream repo for Fizzy's own documentation, deployment guides, and contribution guidelines.
