# Code health metrics

Some things about a codebase only mean something as a trend. Repo-wide coverage of 74% is
a number; 74% after eight weeks of falling from 81% is a decision. This records those
trends on `main` so that people planning work — and agents proposing it — can point at
evidence instead of a feeling.

It is deliberately small. No account, no vendor, no dashboard to provision, no secret
beyond the `GITHUB_TOKEN` that Actions already gives every job. Adopting it in another
repository means copying two files and adding one CI job.

## The shape of it

A metric is **a name and a number**. That is the entire data model, and everything else
follows from refusing to make it richer.

```
collector  →  tmp/metrics/*.json  →  metrics branch  →  trend / chart
```

- **Collectors** are executables under `.metrics/collectors/`. Each prints a JSON object of
  name → number on stdout. That is the whole contract.
- **`bin/metrics collect`** runs them all and leaves their output in `tmp/metrics`.
- **`bin/metrics record`** merges that into one record — commit, timestamp, metrics — and
  appends it to `metrics.jsonl` on the orphan `metrics` branch.
- **`bin/metrics trend`** prints the history. **`bin/metrics page`** rebuilds the chart.

Storage is the part people expect to be hard. It is an append-only JSONL file on a branch
of this repository, written with git plumbing rather than a checkout, so recording never
touches your working tree and a concurrent build just retries its push instead of
corrupting anything. The branch is orphaned: it shares no history with `main`, never merges
into it, and can be deleted and rebuilt from CI without consequence.

## Reading the trend

```bash
bin/metrics trend
```

```
coverage.branch.oss             78.30  ▲ +4.20   ▁▁▄▄█  2026-06-02..2026-08-10 (42)
coverage.line.oss               91.20  ▲ +2.78   ▁▃▅▃█  2026-06-02..2026-08-10 (42)
```

Filter by substring and get machine-readable output when something else is doing the
reading — this is the interface agents should use:

```bash
bin/metrics trend branch --json --limit 30
```

The raw history needs no tooling at all:

```bash
git show origin/metrics:metrics.jsonl
```

For a chart, `index.html` on the metrics branch is regenerated on every record. It is
self-contained — data inlined, no scripts, no requests — so downloading it and opening it
works, and serving it from GitHub Pages works too if you ever want that. Nothing depends on
you setting Pages up.

```bash
bin/metrics page -o tmp/metrics/index.html && open tmp/metrics/index.html
```

## What is tracked today

`coverage.line.oss`, `coverage.branch.oss`, `coverage.line.saas`, `coverage.branch.saas` —
repo-wide line and branch coverage, as SimpleCov measured it after the SQLite and MySQL
legs were collated.

Mode is part of the name because OSS and SaaS measure different trees. They are two metrics
that share a formula, not one metric with a flag.

`tests.flaky.oss`, `tests.broken.oss` — how many tests disagreed with themselves, and how
many failed outright, the last time the nightly repeated the suite under different seeds.
See [flaky tests](flaky-tests.md). Only the nightly produces these, so most commits record
neither.

Note what this is **not**. The [changed-code coverage gate](development.md#running-tests)
is what can fail a build, and it judges only the diff. These numbers judge nothing. A
number that can block a merge invites gaming; a number that only informs invites reading.
Keep them separate.

## Adding a metric

Write an executable that prints JSON, and make it executable. Nothing else — no registry to
update, no config to edit, no change to `bin/metrics`.

```ruby
#!/usr/bin/env ruby
# .metrics/collectors/rubocop
require "json"

offenses = JSON.parse(`bundle exec rubocop --format json`)["summary"]["offense_count"]
puts JSON.generate("rubocop.offenses" => offenses)
```

```bash
chmod +x .metrics/collectors/rubocop
git add .metrics/collectors/rubocop
```

Guidelines that keep this useful rather than merely full:

- **Cheap, or already computed.** The coverage collector reads a report the suite already
  wrote; it does not re-run the suite. A collector that adds minutes to every main build
  will get deleted.
- **Silence over guessing.** Print `{}` when there is nothing to say. `bin/metrics collect`
  skips an empty result, so a checkout that has not run the suite still collects the rest.
- **Name it `subject.aspect.scope`.** Names are the only grouping there is, and they sort.
- **A number, not a verdict.** Record the offense count, not whether it is acceptable.
  Thresholds change with context; the history should not have to be rewritten when they do.

New collectors run in CI as soon as they are merged. Anything they need must be present
wherever `bin/metrics collect` runs — the `coverage` job of `.github/workflows/test.yml`,
and the nightly in `.github/workflows/nightly-flaky.yml`. Both run every collector, which
is why having nothing to say has to be cheap: on a nightly the coverage collector prints
`{}`, and on a main commit the flakiness one does.

## How CI wires it up

The `coverage` job in `test.yml` runs `bin/metrics collect` after collating the adapter
legs, and uploads `tmp/metrics` as a `metrics-oss` / `metrics-saas` artifact. It does this
on `main` only, and regardless of whether the changed-code gate passed — the numbers
describe the commit either way.

The `metrics` job in `ci-saas.yml` waits for both test legs but requires only one to have
passed, then downloads every `metrics-*` artifact and appends one record. Splitting
collection from recording means the many jobs that can *produce* a metric need no write
permission, and the one job that writes the branch needs to know nothing about what it is
writing.

A failing leg contributes nothing rather than contributing bad numbers: its `coverage` job
never runs, so it uploads no artifact. Requiring *both* legs would be stricter but wrong —
forks cannot install the private SaaS gems, so their SaaS leg always fails, and the whole
system would quietly never record anything. Expect OSS-only records outside Basecamp.

The push uses `GITHUB_TOKEN`, and pushes made with it do not trigger workflows, so writing
the branch cannot start another build.

## If something goes wrong

**No records yet.** The branch is created by the first successful `record` on `main`. Until
then `bin/metrics trend` says so.

**A metric stops appearing.** Its collector printed `{}` or failed. Collector failures fail
the CI step loudly; check the `Collect code health metrics` step.

**Records look wrong for a commit.** They are append-only on purpose, and the fix is
forward: the history is a log of what was measured, not an assertion that every measurement
was right. If a record is genuinely garbage, rewrite the branch by hand — nothing depends on
its history being immutable.

**Starting over.** Delete the `metrics` branch. The next main build recreates it.

## Using it in another repository

1. Copy `bin/metrics`. It is stdlib-only Ruby and knows nothing about this project.
2. Write one collector under `.metrics/collectors/`.
3. Add a CI job on your default branch, with `contents: write`, that runs
   `bin/metrics collect && bin/metrics record`.

That is the whole setup. If it needs more than an afternoon, something has been added that
should not have been.
