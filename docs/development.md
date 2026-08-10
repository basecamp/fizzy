## Development

### Setting up

First, get everything installed and configured with:

```sh
bin/setup
bin/setup --reset # Reset the database and seed it
```

And then run the development server:

```sh
bin/dev
```

You'll be able to access the app in development at http://app.fizzy.localhost:3006.

To log in, enter `david@example.com`. In development the verification code is shown on the page itself, under "Psst, here's your code" — no need to check your email.

### Web Push Notifications

Fizzy uses VAPID (Voluntary Application Server Identification) keys to send browser push notifications. For notifications to work in development you'll need to generate a key pair and set these environment variables:

- `VAPID_PRIVATE_KEY`
- `VAPID_PUBLIC_KEY`

Generate them with the `web-push` gem:

```ruby
vapid_key = WebPush.generate_key

puts "VAPID_PRIVATE_KEY=#{vapid_key.private_key}"
puts "VAPID_PUBLIC_KEY=#{vapid_key.public_key}"
```

### Running tests

For fast feedback loops, unit tests can be run with:

```sh
bin/rails test
```

Coverage is off by default, so this stays fast. To run tests with the changed-code
coverage guard:

```sh
bin/coverage                            # the verdict (~60s)
bin/coverage test/models/card_test.rb   # advisory: fast loop while writing tests (~5s)
```

Both compare the working tree against the merge base with `origin/main` and report every
line and branch you added or changed that no test executed.

They differ in more than speed. The first fails the command when anything in your diff is
uncovered. A targeted run only loads the tests you named, so changed code that *other* tests
cover still shows up as uncovered — it prints an advisory banner and always exits 0. Use it
to iterate, not to decide.

**What the gate measures: changed-line coverage — lines and branches — from the non-browser
suite.** That is everything `bin/rails test` runs (249 of the 253 test files, controller and
integration tests included); only the four files in `test/system` are excluded. CI measures
exactly the same thing, so a local run and a pull request always agree.

Scope follows the mode. In OSS mode the gate covers `app/` and `lib/`; in SaaS mode it also
covers `saas/app/` and `saas/lib/`. Mode comes from `Fizzy.saas?`, the same switch the app
uses, so `tmp/saas.txt` works exactly as it does everywhere else. CI gates both, producing
two required checks — `Changed coverage (OSS)` and `Changed coverage (SaaS)`.

System tests still run in CI for correctness, but their coverage is excluded on purpose:
rendering a page marks whatever it touches as covered — class declarations, `def` lines, bare
string literals — which records that code loaded, not that anything checked it. Counting it
would let a click-through satisfy the gate.

A consequence worth knowing: if a code path is reachable only through the browser, the gate
will ask for a test. That is intended. Write a controller or model test for it rather than
relying on a system test to cover it incidentally.

Useful flags: `--compare REF` to pick a different base, `--json` for machine-readable
output, and `--report-only` to re-judge existing coverage data without re-running
tests. Shared settings live in `.undercover` so local runs and CI agree.

A `pre-push` hook runs the gate automatically, but only when the push contains changes to
Ruby under `app/` or `lib/` — doc-only and test-only pushes skip it and cost nothing. It
judges committed state, so uncommitted work in your tree is not considered. `git push
--no-verify` skips it; the required CI check still decides whether the branch can merge.

The HTML report at `coverage/index.html` is the place to look when a warning isn't
obvious — it shows hit counts per line and which branch of a conditional was missed.
To collect coverage without judging it, run `COVERAGE=1 bin/rails test`.

`bin/coverage` compares your working tree against the merge base, so **unstaged edits
to existing files are checked** — you don't need to stage or commit to get a verdict.
The one exception is a **brand-new file git has never seen**: it can't appear in a diff
at all, so the guard stops and asks you to `git add` it first.

The full continuous integration tests can be run with:

```sh
bin/ci
```

### Database configuration

Fizzy works with SQLite by default and supports MySQL too. You can switch adapters with the `DATABASE_ADAPTER` environment variable. For example, to develop locally against MySQL:

```sh
DATABASE_ADAPTER=mysql bin/setup --reset
DATABASE_ADAPTER=mysql bin/ci
```

The remote CI pipeline will run tests against both SQLite and MySQL.

### Outbound Emails

You can view email previews at http://app.fizzy.localhost:3006/rails/mailers.

You can enable or disable [`letter_opener`](https://github.com/ryanb/letter_opener) to open sent emails automatically with:

```sh
bin/rails dev:email
```

Under the hood, this will create or remove `tmp/email-dev.txt`.

## SaaS gem

37signals bundles Fizzy with [`fizzy-saas`](https://github.com/basecamp/fizzy/tree/main/saas), a companion gem that links Fizzy with our billing system and contains our production setup.

This gem depends on some private git repositories and it is not meant to be used by third parties. But we hope it can serve as inspiration for anyone wanting to run fizzy on their own infrastructure.
