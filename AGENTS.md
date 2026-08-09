# Fizzy

Fizzy is a kanban-style project management and issue tracker: cards move
across columns on boards, with comments, mentions, and assignments.

These instructions are defaults with reasons, not law — when the code in
front of you disagrees, take the better path and flag the conflict; invariants
(data loss, security, CI gates) are surfaced, not overridden. Attack your own
diff before calling it done.

## Deploy

Default branch: `main`

Self-hosted deploys run Kamal against `config/deploy.yml` — see `docs/kamal-deployment.md`.

## SaaS mode

For local agent work, `tmp/saas.txt` is the checkout-level SaaS switch used by `bin/setup`. When present, read `saas/AGENTS.md` before continuing. Otherwise, do not apply its instructions.

## Multi-tenancy is URL-based

Accounts get a decimal `external_account_id` URL prefix (`/{account_id}/boards/...`).
`AccountSlug::Extractor` middleware sets `Current.account` and moves the slug
from `PATH_INFO` to `SCRIPT_NAME`, so Rails behaves as if mounted at that
path — route helpers and request specs that assume a bare root will mislead
you. Domain records are account-scoped; identity, session, and authentication
records are the global exceptions. Background jobs serialize and restore
`Current.account` themselves.

A global `Identity` (email-based) can hold `Users` in multiple accounts, so
an email address is not a single account membership. Board access is per-user
`Access` records.

## UUID primary keys

All tables use UUIDv7 keys, base36-encoded to 25 characters. Fixture UUIDs
are generated to sort older than any runtime record, so `.first`/`.last`
stay deterministic in tests — don't "fix" ordering by comparing insertion
order to id order.

## Search is sharded on MySQL, single-index on SQLite

Full-text search runs in the database, not Elasticsearch. On MySQL it is
sharded 16 ways by CRC32 of the account ID (`Search::Record::Trilogy`); on
SQLite it is a single FTS5 index (`Search::Record::SQLite`). Don't assume the
sharded shape when working under SQLite. Models in `app/models/search/`.

## Imports and exports

Data transfer between instances (`app/models/account/data_transfer/`,
`app/models/zip_file`) must work against both local and S3 storage, and
archives can exceed hundreds of gigabytes — stream, never buffer a whole
file.

## Coding style

Before editing or reviewing code, read STYLE.md.
