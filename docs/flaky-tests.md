# Flaky tests

A flaky test is one that disagrees with itself: same code, same commit, different answer.
The suite already runs in a different order every time, so flakes surface on their own. The
problem has never been finding them — it is that by the time you read the red build, the
order that caused it is gone. This is about keeping enough of the run to get it back.

## The suite is already randomized

Nothing needed turning on. Minitest shuffles the order the test classes run in, and
`config.active_support.test_order` (`:random`, the Rails default) shuffles the methods
within each class. Unit, integration, and system tests all get this. Every run prints the
seed it used:

```
Started with run options --seed 4927
```

## Why the seed alone is not enough

`test/test_helper.rb` runs the suite across forked workers with **work stealing on**, which
is the right trade for a build you are waiting on: an idle worker takes from a busy one, so
nobody finishes early and waits. The cost is that which worker runs which test depends on
timing, so the same seed gives a different run each time. Measured on this repo, two runs at
the same seed placed 70 tests differently.

Turn work stealing off and the round-robin distributor assigns tests to workers strictly in
arrival order — and arrival order is the shuffle, which comes from the seed. Seed plus
worker count then replays a run exactly, all the way down to which tests preceded which on
each worker.

So to reproduce an order-dependent failure:

```bash
WORK_STEALING=false PARALLEL_WORKERS=4 bin/rails test --seed 4927
```

Run the whole suite, not the one test. Filtering to the failing test throws away the order
that caused the failure, which is the only thing being reproduced.

## The nightly hunt

`.github/workflows/nightly-flaky.yml` runs `bin/flaky` at 03:17 UTC. That repeats the suite
three times — different seed each time, work stealing off, four workers — and sorts what it
finds into two piles:

- **Flaky**: passed under one seed, failed under another. This is the thing being hunted.
- **Broken**: failed under every seed. Main is red; that is not flakiness, and it is the
  only outcome that fails the job.

The seeds must differ, and this is the part that is easy to get backwards. With work
stealing off, one seed run three times is the *same run* three times — an order-dependent
test fails all three and gets filed as broken rather than flaky. Varying the seed is what
makes it flip; work stealing being off is what makes the flip reproducible afterwards.

Being nightly buys one more thing for free: it runs at a different hour than any pull
request, and marches through month, year, and DST boundaries over time. Tests that depend
on the wall clock turn up here and nowhere else.

## Reading what it found

```
FLAKY (1) — passed under one seed and failed under another

  Card::EntropyTest#test_postpones_after_the_period
    pass (seed 262200) · pass (seed 981826) · fail (seed 165544)
    Expected 2 to be nil.
    Ran on worker 2. 3 tests preceded it only when it failed:
      BoardTest#test_archiving
      Card::MovementTest#test_moves_across_columns
      SearchTest#test_reindexes

    Reproduce:
      WORK_STEALING=false PARALLEL_WORKERS=4 bin/rails test --seed 165544
```

The suspect list is the useful part. It is every test that ran ahead of the failure on the
same worker in *all* of the failing runs, minus everything that ran ahead of it in *any* of
the passing runs — so it is the set of tests that were present when it failed and absent
when it passed. Bisect that list, not the suite. Tests on the other workers are in separate
processes with their own databases and could not have left anything behind.

An empty suspect list is informative too: it means the order was not the difference, so look
at the clock, at `tmp/`, at Active Storage, at anything shared that lives outside the
per-worker database.

The full lists, per-run outcomes, and the raw execution logs are in the `flaky-report`
artifact on the workflow run. `tmp/flaky/run-N/*.jsonl` has one line per test — worker,
position, outcome — which is enough to reconstruct any run completely.

## Running it yourself

```bash
bin/flaky
```

Repeats the whole suite three times, which takes as long as that sounds. Narrow it while you
are chasing something specific:

```bash
bin/flaky --runs 5 --workers 4 test/models
```

`--json` prints the summary instead of the prose report. `bin/flaky --help` lists the rest.

To record per-test execution without the repetition, set `FLAKY_LOG` on an ordinary run:

```bash
FLAKY_LOG=tmp/flaky/once WORK_STEALING=false PARALLEL_WORKERS=4 bin/rails test
```

That is the same logging the hunt uses, and it costs nothing when the variable is unset.

## The number that gets kept

`tests.flaky.oss` and `tests.broken.oss` go into the [code health
metrics](code-health-metrics.md) every night, so the trend is readable:

```bash
bin/metrics trend flaky
```

One night is a coin flip; thirty nights is a measurement. Neither number gates anything, on
purpose — a flakiness count that can block a merge is a count people learn to suppress
rather than one they fix.
