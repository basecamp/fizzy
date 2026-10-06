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

Full-text search runs in the database through ActiveSearch, not Elasticsearch.
On MySQL it is sharded 16 ways by CRC32 of the account ID, through our own
`ActiveSearch::StoreAdapters::MysqlSharded`; on SQLite it is a single FTS5 index
through the gem's `sqlite` adapter. Don't assume the sharded shape when working
under SQLite. Index schema, adapter registration and the document class are all
in `config/search.rb`.

Models join the index with `has_search`, and the store adapter owns every
read and write. Don't reach for a search table directly — go through
`ActiveSearch.index(:searchable)`.

## Imports and exports

Data transfer between instances (`app/models/account/data_transfer/`,
`app/models/zip_file`) must work against both local and S3 storage, and
archives can exceed hundreds of gigabytes — stream, never buffer a whole
file.

## New third parties and personal data

If a change sends customer or visitor personal data to a new third party or a new service, sends new kinds of personal data to a third party we already use, or changes what personal data we collect, say so in the PR and file a card on the [Trust & Compliance On Call board](https://app.basecamp.com/2914079/buckets/48697456/card_tables/10263279046) before it ships. A new subprocessor needs notice before we authorize it ([DPA §5.2](https://37signals.com/policies/privacy/dpa)), and customers then have 10 business days to object (§5.3), so file early. The current list is at <https://37signals.com/policies/privacy/fizzy-subprocessors>. Reviewers, human or agent: call this out when you see it.

Outside contributors without Basecamp access: flag it in the PR, and a maintainer will file the card.

## Coding style

Before editing or reviewing code, read STYLE.md.
