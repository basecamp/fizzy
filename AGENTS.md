# Fizzy

Guidance for AI coding agents working with this repository.

Fizzy is a kanban-style project management and issue tracker: cards move across columns on boards, with comments, mentions, and assignments.

## Deploy

Default branch: `main`

Self-hosted deploys run Kamal against `config/deploy.yml` — see `docs/kamal-deployment.md`.

## SaaS mode

For local agent work, `tmp/saas.txt` is the checkout-level SaaS switch used by `bin/setup`. When present, read `saas/AGENTS.md` before continuing. Otherwise, do not apply its instructions.

## Architecture Overview

### Multi-Tenancy (URL-Based)

Fizzy uses **URL path-based multi-tenancy**:
- Accounts have a unique decimal `external_account_id` used in URL prefixes
- URLs are prefixed: `/{account_id}/boards/...`
- Middleware (`AccountSlug::Extractor`) extracts the account ID from the URL and sets `Current.account`
- The slug is moved from `PATH_INFO` to `SCRIPT_NAME`, making Rails think it's "mounted" at that path
- Tenant-scoped domain records are account-isolated; global identity, session, and authentication records are exceptions
- Background jobs automatically serialize and restore account context

**Key insight**: This architecture allows multi-tenancy without subdomains or separate databases, making local development and testing simpler.

### Authentication & Authorization

Passwordless magic link authentication. A global `Identity` (email-based) can have `Users` in multiple Accounts, so an email is not a single account membership. Users have roles: owner, admin, member, system. Board-level access control via `Access` records.

### Entropy System

Cards automatically "postpone" (move to "not now") after inactivity:
- Account-level default entropy period
- Board-level entropy override
- Prevents endless todo lists from accumulating
- Configurable via Account/Board settings

### UUID Primary Keys

All tables use UUIDs (UUIDv7 format, base36-encoded as 25-char strings):
- Custom fixture UUID generation maintains deterministic ordering for tests
- Fixtures are always "older" than runtime records
- `.first`/`.last` work correctly in tests

### Background Jobs (Solid Queue)

Database-backed job queue (no Redis):
- Custom `FizzyActiveJobExtensions` prepended to ActiveJob
- Jobs automatically capture/restore `Current.account`
- Mission Control::Jobs for monitoring

Recurring tasks are declared in `config/recurring.yml`.

### Sharded Full-Text Search

Full-text search runs in the database, not Elasticsearch. On MySQL it is sharded 16 ways by CRC32 of the account ID (`Search::Record::Trilogy`); on SQLite it is a single FTS5 index (`Search::Record::SQLite`). Don't assume the sharded shape when working under SQLite. Models in `app/models/search/`.

### Imports and exports

Allow people to move between OSS and SAAS Fizzy instances:
- Exports/Imports can be written to/read from local or S3 storage depending on the config of the instance (both must be supported)
- Must be able to handle very large ZIP files (500+GB)
- Models in `app/models/account/data_transfer/`, `app/models/zip_file`

## Coding style

Before editing or reviewing code, read STYLE.md.

## Test coverage

Every line you add or change must be executed by a test, and every conditional branch on
those lines must be taken in both directions. CI enforces this on changed code only — the
existing suite's gaps are not your problem, the diff you are writing is.

**Workflow.** Run `bin/coverage <test paths>` for a fast loop while writing tests. Run
`bin/coverage` with no arguments before calling a change complete. A targeted run prints an
advisory banner and never fails, because it reports changed code covered by tests it didn't
run as if it were uncovered.

**What the gate measures:** changed-line coverage — lines *and* branches — from the non-browser
suite. That is everything `bin/rails test` runs, controller and integration tests included; only
`test/system` is excluded. CI measures the same thing, so your local verdict and the one on the
pull request always agree.

Scope follows the mode: `app/` and `lib/` always, plus `saas/app/` and `saas/lib/` when
`Fizzy.saas?` is true. CI gates both modes.

Browser tests are excluded deliberately: rendering a page marks whatever it touches as covered,
which records that code loaded rather than that anything checked it. So if a code path is
reachable only through the browser, the gate will ask for a test — write a controller or model
test for it instead of leaning on a system test.

Editing existing files needs no staging — unstaged edits are checked. But if you create a
new file under `app/` or `lib/`, `git add` it: a file git has never seen cannot appear in a
diff, so the guard refuses to run until you do.

**Reading a branch warning.** This is the part that trips people up: the line ran, but one
path through it never did — the `else`, the `nil` case, the early return, the untriggered
`rescue`, the right side of an `||`. Fix it by writing a test that drives the code down that
path. Do not restructure code to have fewer branches just to satisfy the tool.

**The anti-pattern to refuse.** Coverage records whether a line *ran*, not whether it is
*correct*. A test that executes a branch without asserting its outcome satisfies the tool and
defeats the entire purpose. Never add assertion-free tests, and never weaken an assertion, to
move this number.

Do not silence warnings with SimpleCov `:nocov:` comments. The only bypass is a
`Coverage-exempt: <reason>` trailer on the commit message; it needs a real reason (a
`commit-msg` hook rejects an empty one) and it is visible in review.

A `pre-push` hook runs the gate when a push touches Ruby under `app/` or `lib/`, so expect
roughly a minute's pause there rather than treating it as a hang. It judges committed state
only. Never reach for `git push --no-verify` to get around a finding — fix the coverage.
