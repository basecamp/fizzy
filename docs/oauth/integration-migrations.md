# OAuth stack: migrations for the manual beta run

Integration branch `oauth-integration-2026-10-15`, rebuilt from `main` at
`27d0d2e6b` on 2026-10-17 (first cut from `2568389d9` on 2026-10-15). Throwaway: it exists to put every migration in the
OAuth stack on a beta host so they can be run by hand before any of the PRs
land. Nothing here merges to `main`.

## What's merged

Each PR's head at the time, merged in dependency order with a merge commit
named for the PR:

| PR | Branch | Head |
|---|---|---|
| #2296 | `oauth` | `f64ab634ab6e` |
| #3080 | `oauth-dcr-https` | `5d74b5309ec2` |
| #3081 | `oauth-refresh-tokens` | `017291f81210` |
| #3082 | `oauth-confidential-clients` | `274c56688b18` |
| #3158 | `oauth-bearer-challenge` | `600d34776249` |
| #3160 | `oauth-refresh-replay` | `0956b57aafc7` |
| #3161 | `oauth-grant-idle-expiry` | `9bf097414cdb` |
| #3159 | `oauth-client-sweep` | `eac532ca82a4` |
| #3163 | `oauth-token-prefixes` | `918f2566ddca` |
| #3169 | `oauth-delegate-resources` | `d0b4a26f7872` |
| #3192 | `oauth-token-digests` | `617edb87b` |
| #3191 | `test/pin-shipped-client-auth` | `98572aaaf` |

The train is linear since 2026-10-17 (#3160 restacked onto #3158), so the merges
don't conflict.

Beyond the merges, two commits of the branch's own and this file:
`saas/config/deploy.beta.yml` sets the web role's `cmd` so a beta boot does not
migrate (see "Deploying without migrating" below), and
`saas/config/database.yml` gives the `MIGRATE=1` connection a 5 s
`lock_wait_timeout` (see "The lock that matters").

## Beta shares the production database

`saas/config/database.yml` ends `beta: *production`, and `deploy.beta.yml` points
beta at `fizzy-mysql-primary`. **Migrating on beta1 is migrating
`fizzy_production`.** Every migration below is additive (new tables, new
nullable columns, new indexes), so `main`, running in production, keeps working
against the migrated schema: it never reads the new columns, and its inserts
leave them NULL.

No migration here drops a column of a table `main` uses, and that is
deliberate. `main` runs with `partial_inserts` off (`load_defaults 8.1`), so
each INSERT names every column the process has cached, and each process caches
a table's columns the first time it uses the model (there is no schema cache
dump). Dropping such a column would fail every insert from a process that had
cached it, until that process restarted. So #10 drops only from
`oauth_clients` and `oauth_retired_refresh_tokens`, which `main` doesn't have.
`identity_access_tokens.refresh_token` stays: #3192's `Identity::AccessToken`
ignores it, #9 empties it, and #3203 (D3) drops it beside `token`. D3 runs
only once every process runs D2's code, which ignores both. No restart is
needed. The `down`s do drop columns `main` has cached (see "Undoing it").

Only the solid queue and solid cache databases are beta's own. Beta's
`config/recurring.yml` section runs only Solid Queue maintenance, so the new
OAuth sweeps (`Oauth::Client.cleanup`, `Identity::AccessToken.cleanup`,
`Oauth::RetiredRefreshToken.cleanup`) do not run from beta.

## The migrations, in the order Rails runs them

All ten are on the primary database (`fizzy_production`). None touch
`fizzy_saas_production`, the solid databases, or `saas/db/migrate`. None
backfill data except #9, which digests every existing token in place (`updated_at`
unmoved); otherwise existing rows keep NULL in every new column, and the code reads
NULL as "not from an OAuth grant" (a personal access token, a session-made
webhook, a session-registered push subscription).

Production sizes are InnoDB's estimates from PMM
(`mysql_info_schema_table_rows` / `_size`, `fizzy_production`, 2026-10-15).
The primary runs Percona Server 8.4.8. The `oauth_*` tables do not exist in
production yet, so none of these has been applied there.

| # | Version / file | PR | What it does | Production table | MySQL 8.4 DDL |
|---|---|---|---|---|---|
| 1 | `20251231163456_add_oauth.rb` | #2296 | `CREATE TABLE oauth_clients` (uuid id, `client_id` unique, `name`, `redirect_uris` json, `scopes` json, `trusted`, `dynamically_registered`, timestamps). `add_reference :identity_access_tokens, :oauth_client` (uuid, nullable, indexed, no FK) | `identity_access_tokens`: ~3,500 rows, 0.45 MB data + 0.2 MB index | New table: no lock on anything existing. ADD COLUMN nullable: INSTANT. ADD INDEX: INPLACE, LOCK=NONE, sub-second at this size |
| 2 | `20260827090000_add_authorization_code_jti_to_identity_access_tokens.rb` | #2296 | `add_column :identity_access_tokens, :authorization_code_jti, :string` + unique index | `identity_access_tokens` (as above) | INSTANT add, then online unique index; every existing row is NULL, so no duplicate can fail it |
| 3 | `20260827100000_add_oauth_token_expiry.rb` | #3081 | `change_table :identity_access_tokens, bulk: true`: `refresh_token` string, `expires_at` datetime, unique index on `refresh_token` | `identity_access_tokens` (as above) | One ALTER; the index makes it INPLACE, LOCK=NONE. All NULL, no duplicates |
| 4 | `20260827110000_add_oauth_client_secrets.rb` | #3082 | `change_table :oauth_clients, bulk: true`: `client_secret` string, `token_endpoint_auth_method` string NOT NULL default `"none"` | `oauth_clients`: created by #1, empty | Instant on an empty table |
| 5 | `20261006120000_create_oauth_retired_refresh_tokens.rb` | #3160 | `CREATE TABLE oauth_retired_refresh_tokens` (uuid id, `access_token_id` NOT NULL, `refresh_token` unique, `successor_refresh_token`, `created_at`; indexes on `access_token_id` and `created_at`) | new | New table |
| 6 | `20261006130000_add_oauth_client_to_push_subscriptions.rb` | #3169 | `add_reference :push_subscriptions, :oauth_client` (uuid, nullable, indexed, no FK) | `push_subscriptions`: ~1,400 rows, 1.6 MB data + 0.6 MB index | INSTANT add + online index, sub-second |
| 7 | `20261006130100_add_attribution_to_webhooks.rb` | #3169 | `add_reference :webhooks, :creator` and `add_reference :webhooks, :created_via` (uuid, nullable, indexed, no FK) | `webhooks`: ~1,500 rows, 0.5 MB data + 0.4 MB index | Two INSTANT adds + two online indexes, sub-second |
| 8 | `20261015120000_add_token_digests.rb` | #3192 | `change_table :identity_access_tokens, bulk: true`: `token_digest`, `refresh_token_digest` (string 80), a unique index on each. `add_column :oauth_clients, :client_secret_digest` (string 80) | `identity_access_tokens`: ~3,500 rows | One ALTER, INPLACE LOCK=NONE. Every row starts NULL, so neither unique index can fail |
| 9 | `20261015120100_backfill_token_digests.rb` | #3192 | **Data only, no DDL.** Refuses duplicate `token`s first. Then one `UPDATE … WHERE id = ?` per row: `token_digest` for every token (OAuth rows also get `token` NULLed), `refresh_token_digest` (and `refresh_token` NULLed) and `client_secret_digest` where those columns still exist. `updated_at` doesn't move. `disable_ddl_transaction!`, batches of 500. `down` is a no-op | `identity_access_tokens` | Row locks only, ~3,500 single-row updates on the primary key, a few seconds |
| 10 | `20261015120200_drop_plaintext_oauth_credentials.rb` | #3192 | Drop `oauth_clients.client_secret`. Drop and recreate `oauth_retired_refresh_tokens` keyed by digest, with `successor_payload` text. Leaves `identity_access_tokens` alone: its `refresh_token` goes in D3 | the empty `oauth_*` tables only | DROP COLUMN is INSTANT. The `oauth_*` tables are empty in production, and `main` has no model for either |

#1 to #8 and #10 are reversible, so each has a working `down`; #9's `down` is a
no-op. All ten are portable: they ran up, down and up again on
SQLite and on MySQL 8.4 (see "Verification").

### The lock that matters

At these sizes the copy work is nothing. What can hurt is the metadata lock:
every ALTER briefly takes an exclusive MDL on its table, waits for open
transactions on that table to finish first, and while it waits every new query
on the table queues behind it. `identity_access_tokens` is read on every API
request that sends a Bearer token. The `MIGRATE=1` connection has no
`max_execution_time`, and the server's `lock_wait_timeout` is a year, so on
its own a stuck ALTER waits for as long as the blocking transaction lives.

This branch's `saas/config/database.yml` sets `lock_wait_timeout` to 5 s on the
`MIGRATE=1` connection only (the app connection keeps the server's): a blocked
ALTER gives up with `Lock wait timeout exceeded`, and the queries behind it run.
Check for long-running transactions just before anyway
(`information_schema.innodb_trx`), so a step doesn't have to fail first.

A step that gives up partway leaves what it already did. MySQL DDL doesn't roll
back, and #1, #2, #6, #7, #8 and #10 each run several statements, so rerunning
the step can then fail on the part already done (`Table 'oauth_clients' already
exists`, `Duplicate column name`). Its version is not in `schema_migrations`.
Compare `SHOW CREATE TABLE` with the migration's file, undo what it did by hand,
and rerun the step.

### Versions out of order with main

Four of the seven (#1 to #4) are older than `main`'s newest migration,
`20260828120000_create_identity_transfers`. `db:migrate` still runs them
(Rails runs each version missing from `schema_migrations`, oldest first), but
once applied the history interleaves:

```
20251231163456  AddOauth                               (this stack)
20260827090000  AddAuthorizationCodeJti…               (this stack)
20260827100000  AddOauthTokenExpiry                    (this stack)
20260827110000  AddOauthClientSecrets                  (this stack)
20260828120000  CreateIdentityTransfers                (main)
20261006120000  CreateOauthRetiredRefreshTokens        (this stack)
20261006130000  AddOauthClientToPushSubscriptions      (this stack)
20261006130100  AddAttributionToWebhooks               (this stack)
```

**Never undo this stack with `db:rollback`.** Rollback goes by version, not by
when a migration ran: `db:rollback:primary STEP=7` reverts the three October
migrations, then `CreateIdentityTransfers` (dropping `identity_transfers`, a
`main` table), then three of this stack's, and leaves `AddOauth` applied. That
is what it did in the local SQLite round trip. (A bare `db:rollback` refuses
anyway on this multi-database app.) Undo by version, newest first, as below.

## Deploying without migrating

What migrates on boot:

- `bin/docker-entrypoint` runs `MIGRATE=1 ./bin/rails db:prepare` when, and only
  when, the container's command is exactly `./bin/thrust ./bin/rails server`,
  the Dockerfile's default CMD and what the web role runs. `db:prepare` runs
  every pending migration on every database. On beta that is production.
- The jobs role runs `bin/jobs` and never migrates.
- No Kamal hook migrates: `pre-connect` checks Tailscale and SSH, `pre-build`
  and `pre-deploy` build and reboot the hotcell accessory, `post-deploy`
  notifies Dash and Basecamp. `--skip-hooks` would change nothing about
  migrations, and would skip the hotcell reboot.
- There is no environment variable that turns the entrypoint's `db:prepare` off.

So this branch sets the beta web role's `cmd` to `bin/thrust ./bin/rails
server`: the same server, a command the entrypoint doesn't match. It holds for
the deploy and for any later restart of that container. `bin/kamal config -d
beta1` renders the web container as `…/fizzy:<sha> bin/thrust ./bin/rails
server`; jobs stays `bin/jobs`.

It does not protect against a different branch carrying these migrations being
deployed to beta1 (an individual OAuth PR branch, say): that deploy migrates
production on boot.

Between the deploy and the manual migration, beta1 runs this code against the
old schema, so anything that touches the new columns fails there (Bearer-token
API requests, webhook creation, push delivery). To skip that window, migrate
first with the new image (option B below).

## Pre-flight

Each line is checked in "Production safety" below.

1. `Production/OAUTH_TOKEN_PEPPER` exists in 1Password (see "Before beta boots
   #3192").
2. Run each step with `db:migrate:up:primary VERSION=…`, or all ten with a bare
   `db:migrate:primary`. Never `db:migrate:primary VERSION=…`: on a database
   where `main`'s `20260828120000_create_identity_transfers` is applied, a
   target older than it migrates *down*. `VERSION=20260827100000` reverts
   `CreateIdentityTransfers`, dropping `identity_transfers` in production, and
   runs none of this stack's. And never `db:rollback` (see "Versions out of
   order with main").
3. Just before, check `information_schema.innodb_trx` on the primary for
   long-running transactions. A blocked ALTER now gives up after 5 s on its
   own; if one does, see "The lock that matters" before rerunning.
4. Run #1 to #10 in one session. Production needs no restart: no step drops
   a column `main` uses (see "Beta shares the production database"). A
   production deploy or restart during the run needs nothing either.
5. Then restart beta1 as below.
6. To undo, run every `down` in one loop and restart production at once (see
   "Undoing it").

Contingency: if a production process ever reports `Unknown column` on an
insert after a migration here, `bin/kamal app boot -d production` reloads
every process's columns.

## Running it

From a checkout of this branch, Tailscale up, SaaS mode on:

```sh
git switch oauth-integration-2026-10-15 && git pull
bin/rails saas:enable
bin/kamal lock status -d beta1   # beta1 is the only beta: the others have no hosts in deploy.beta.yml
```

`MIGRATE:1` is what switches the connection to `MYSQL_ALTER_USER` with no
statement time limit. Without it, the app user has a 5 s `max_execution_time`
and may not hold ALTER at all. Put the command straight after `exec` and `-e`
last, because Kamal's `-e` swallows the arguments after it. `-p -r web` runs
one fresh container on the single web host, so the migration runs exactly once.

### Option A: deploy, then migrate

```sh
bin/kamal deploy -d beta1

# Confirm the web container is running the non-migrating command:
bin/kamal app details -d beta1 -r web

bin/kamal app exec 'bin/rails db:migrate:status:primary' -d beta1 -p -r web -e MIGRATE:1
```

Then one at a time, oldest first, checking status between steps:

```sh
bin/kamal app exec 'bin/rails db:migrate:up:primary VERSION=20251231163456' -d beta1 -p -r web -e MIGRATE:1
bin/kamal app exec 'bin/rails db:migrate:up:primary VERSION=20260827090000' -d beta1 -p -r web -e MIGRATE:1
bin/kamal app exec 'bin/rails db:migrate:up:primary VERSION=20260827100000' -d beta1 -p -r web -e MIGRATE:1
bin/kamal app exec 'bin/rails db:migrate:up:primary VERSION=20260827110000' -d beta1 -p -r web -e MIGRATE:1
bin/kamal app exec 'bin/rails db:migrate:up:primary VERSION=20261006120000' -d beta1 -p -r web -e MIGRATE:1
bin/kamal app exec 'bin/rails db:migrate:up:primary VERSION=20261006130000' -d beta1 -p -r web -e MIGRATE:1
bin/kamal app exec 'bin/rails db:migrate:up:primary VERSION=20261006130100' -d beta1 -p -r web -e MIGRATE:1
bin/kamal app exec 'bin/rails db:migrate:up:primary VERSION=20261015120000' -d beta1 -p -r web -e MIGRATE:1
bin/kamal app exec 'bin/rails db:migrate:up:primary VERSION=20261015120100' -d beta1 -p -r web -e MIGRATE:1
bin/kamal app exec 'bin/rails db:migrate:up:primary VERSION=20261015120200' -d beta1 -p -r web -e MIGRATE:1
```

Or all ten at once: `bin/kamal app exec 'bin/rails db:migrate:primary' -d beta1 -p -r web -e MIGRATE:1`.
Then restart beta1 so its processes load the new columns: `bin/kamal app
boot -d beta1`. The web container keeps the non-migrating command; nothing is
pending anyway. Production needs no restart.

### Option B: migrate with the new image, then deploy

```sh
bin/kamal build push -d beta1
bin/kamal app exec 'bin/rails db:migrate:status:primary' -d beta1 -p -r web --version=$(git rev-parse HEAD) -e MIGRATE:1
# …the same db:migrate:up:primary steps, each with --version=$(git rev-parse HEAD)…
bin/kamal deploy -d beta1 --skip-push
```

`build push` runs the `pre-build` hook (it publishes the hotcell image), and the
deploy's `pre-deploy` hook reboots hotcell onto it.

### Undoing it

By version, newest first, never `db:rollback`:

```sh
for v in 20261015120200 20261015120100 20261015120000 20261006130100 20261006130000 20261006120000 20260827110000 20260827100000 20260827090000 20251231163456; do
  bin/kamal app exec "bin/rails db:migrate:down:primary VERSION=$v" -d beta1 -p -r web -e MIGRATE:1
done
bin/kamal app boot -d production
```

This drops `oauth_clients`, `oauth_retired_refresh_tokens` and the new columns,
along with anything beta wrote to them. Personal access tokens keep their
plaintext throughout, so `main` keeps authenticating them. Undo only once
nothing is running this branch's code; prefer redeploying `main` to beta1 and
leaving the schema be, which `main` runs on.

By the time of an undo, production's processes have cached the new columns of
`identity_access_tokens`, `push_subscriptions` and `webhooks`. From the first
`down` that drops one until production restarts, those processes fail every
personal access token, push subscription and webhook they create (for example `Unknown
column 'oauth_client_id'`). Reads keep working. Hence one loop and the restart
straight after.

#9 and #10 don't fully undo. #9 empties any plaintext refresh token it
digests, and #10's `down` restores an empty `client_secret` column and an
empty retired-token table, not their values. None of those hold anything in
production, where OAuth has never run.

### When the PRs land

`main`'s production deploy runs `db:prepare` on boot as usual, finds these
versions already in `schema_migrations`, and does nothing.

## OAuth stays dark on beta

`config/environments/beta.rb` loads `production.rb`, which sets
`config.x.oauth.acceptance_enabled = ENV["OAUTH_ACCEPTANCE_ENABLED"] == "true"`.
`deploy.beta.yml` neither sets `OAUTH_ACCEPTANCE_ENABLED` (or
`OAUTH_ISSUANCE_ENABLED` / `OAUTH_PILOT_CLIENT_IDS`) in `env.clear` nor lists it
in `env.secret`, so it is unset in the container. Discovery, registration,
authorize and token all answer 404, and OAuth bearer tokens are refused.
Personal access tokens and sessions work as before, except where #3158
deliberately changes their failure responses (see "Verification").

## Verification

Run on thelio against a dedicated MySQL 8.4 container, at the merge head before
this file and the deploy commit, which change no Ruby.

Migration round trip, from `main`'s schema loaded by `main`'s code (so
`schema_migrations` holds only `main`'s versions), then `db:migrate`, then
`db:migrate:down:primary` for each version newest first, then `db:migrate`
again:

- **SQLite (OSS):** up, down and up all succeed. After down, the dump matches
  `main`'s `db/schema_sqlite.rb`. After up, it differs from the committed
  `schema_sqlite.rb` in formatting only. Columns come out in physical order,
  where the committed file sorts them. The new string columns also lack
  `limit: 255`, because `config/initializers/table_definition_column_limits.rb`
  only applies the limit and its CHECK constraint in `create_table`, not
  `add_column`/`change_table`. That predates this stack, and MySQL is
  unaffected (its VARCHAR default is 255 anyway).
- **MySQL, SaaS:** up, down and up all succeed. After down, the dump matches `main`'s `db/schema.rb`. After up, it differs from the committed `schema.rb` in column order only: the same 12 column lines, physical order where the committed file sorts them. Nothing else differs, so the committed schema is consistent with what the migrations build.
- **MySQL, OSS (`DATABASE_ADAPTER=mysql`):** the same result as SaaS.

Test suites:

| Suite | Result |
|---|---|
| rubocop, brakeman | pass |
| SaaS (MySQL) | 2247 tests, **2 failures** |
| OSS (SQLite) | 2077 tests, **2 failures** |
| OSS (MySQL) | 2077 tests, **2 failures** |
| SaaS system | 41 tests, pass |
| OSS system | 41 tests, pass |

The same two tests fail in all three suites, and they are the only failures.
Both are #3191's pins, failing against #3158's deliberate changes:

- `ShippedClientAuthenticationTest#test_a_read_token_may_read_but_not_write`:
  a read-only PAT writing gets **403** `insufficient_scope` where it got 401
  (`Authentication#authenticate_with_bearer_token`, RFC 6750 §3.1).
- `ShippedClientAuthenticationTest#test_a_JSON_request_without_credentials_redirects_to_login`:
  a JSON request with no credentials and no `session_token` cookie gets **401**
  with a Bearer challenge where it got a 302 to `/session/new`
  (`Authentication#bearer_challengeable_request?`). With a bad cookie it
  still redirects.

#3191 asks for this: the stack must "keep them green … or change one
deliberately and say so". Whether shipped clients (the CLI, the native apps)
tolerate these two changes is a decision for the stack, not this branch. The
branch leaves both tests failing as they are.

## Re-verification, 2026-10-17 rebuild

On thelio against a dedicated MySQL 8.4 container, at the merge of #3191 on the
linear train (`79c0c1a08`):

- Migration round trip on MySQL (OSS), from `main`'s schema loaded by `main`'s
  code: all ten up, all ten down newest first, all ten up. The dump differs
  from the committed `db/schema.rb` in column order only.
- SaaS (MySQL) 2308 tests, OSS (SQLite) 2138, OSS (MySQL) 2138: **0 failures,
  0 errors**. #3191's pins now pass: D6 kept shipped clients' answers in #3158
  (a read-only personal access token's write keeps its 401, and a JSON request
  with no credentials keeps its 302), which supersedes the "Verification" note
  above about two failing pins.

## Re-verification, pepper rename

#3192 renamed its pepper variable from `TOKEN_DIGEST_PEPPER` to
`OAUTH_TOKEN_PEPPER` (head `4cfbbd2ec21b`), which changes no migration. On
thelio against a dedicated MySQL 8.4 container, at the merge of #3191 on the
rebuilt branch (`7a4b990bd`): SaaS (MySQL) 2309 tests, OSS (SQLite) 2139, OSS
(MySQL) 2139, **0 failures, 0 errors**; rubocop clean. The one new test pins
the variable's name.

## Re-verification, issuer without a trailing slash

#3192 (head `09523ade5f33`) now advertises the issuer as the bare origin
(`https://app.fizzy.do`, as bc3), in the metadata, the `iss` redirect
parameter and the protected resource's `authorization_servers`; it changes no
migration. On thelio against a dedicated MySQL 8.4 container, at the merge of
#3191 (`e391528fe`): SaaS (MySQL) 2310 tests, OSS (SQLite) 2140, OSS (MySQL)
2140, **0 failures, 0 errors**; rubocop clean.

## Production safety

Does `main`, running in production, keep working while beta1 migrates
`fizzy_production`, and after? Checked on thelio against dedicated MySQL 8.4.11
containers, `main` at `27d0d2e6b`. First at `06eb83531`, where #10 still dropped
`identity_access_tokens.refresh_token`. That run found the column-cache hazard
in 2 below, and #3192 then moved the drop to D3 (`617edb87b`, "Keep
identity_access_tokens.refresh_token until it can go with token"). Items 1, 2
and 4 were rerun on this branch's rebuild, at the merge of #3191
(`9ac2cb078`); the results below are from that rerun unless marked.

1. **`main`'s suite on the migrated schema.** `main`'s code loaded `main`'s
   schema into `fizzy_test`, and this branch's code ran all ten migrations on
   top. Then `main`'s SaaS suite ran serially (`PARALLEL_WORKERS=1`; parallel
   workers would load fresh databases from `schema.rb`). `schema_sha1` still
   matched `main`'s `schema.rb`, so the suite didn't reload the schema; a dump
   after the run matched the one before. Result: 1919 tests, **0 failures, 0
   errors**, 1 skip, the same `bin/rails test` CI runs. (The same with #10 as
   it was, and with only #1 to #9 applied.)
2. **The column cache.** Each check is a `main` process that loads
   `Identity::AccessToken`'s columns at a chosen point, waits while the train
   migrates, then creates, finds, updates and deletes personal access tokens:
   - Loaded before #1, held through all ten: everything works.
   - Loaded between #3 and #10, held past #10: everything works. At
     `06eb83531`, before the split, create failed with `Unknown column
     'refresh_token' in 'field list'`; find, update and delete worked.
   - A process started after #10: everything works.
   - Loaded on the fully migrated schema, held through every `down`: **create
     fails** (`Unknown column 'oauth_client_id'`). Find, update and delete
     work, and a fresh process works. Hence the restart after an undo.

   #3192's `test/migrations/drop_plaintext_oauth_credentials_test.rb` holds
   this in the suite. A model with no ignored columns, as `main`'s, caches
   the table's columns before #10, then creates a token after it. Against the
   old #10 it fails with that same `Unknown column 'refresh_token'`. D3's
   `drop_identity_access_token_plaintext_test.rb` does the same for D3's drop,
   with a model that ignores both columns, as D2's does.
3. **Personal access tokens across the mixed period** (at `06eb83531`; the
   split changes no lookup or write path). `main` made token A
   before #1 and B between #8 and #9. After #9 both have a digest and keep
   their plaintext, and so does every fixture token. `main` made C after #10;
   C has no digest. The train's `find_honored`, the Bearer path, finds A, B and
   C. Finding C gives it its digest, on a primary-datacenter host (the test
   environment counts as one). Every token with its case swapped is refused.
   The train made D, which stores a `fizzy_pat_` token as plaintext and digest.
   `main`'s `Identity.find_by_permissable_access_token` authenticates A, B, C
   (after healing) and D, for GET and POST.
4. **Online DDL.** The SQL log captured all 19 statements the ten migrations
   issue: the 21 of `06eb83531` less #10's `DROP INDEX` and `DROP COLUMN` on
   `identity_access_tokens`. They ran again on `main`'s schema with the
   algorithm spelled out, so MySQL refuses rather than falls back. Every
   column add and drop ran with `ALGORITHM=INSTANT`. Every index ran with
   `ALGORITHM=INPLACE, LOCK=NONE`, and so did the two bulk ALTERs that add
   columns and unique indexes together (#3, #8). The rest create or drop the
   empty `oauth_*` tables. 19 of 19 ran as specified. D3's statement then ran
   on the result as written (`DROP INDEX …refresh_token, DROP COLUMN
   refresh_token, DROP COLUMN token, ALGORITHM=INPLACE, LOCK=NONE`). These were empty tables of `main`'s current definition;
   production's are the same definition with rows. Neither INSTANT nor INPLACE
   depends on the row count. Where INSTANT isn't available (a compressed table,
   64 instant changes already made), MySQL falls back to INPLACE, which is
   still online.
5. **The lock timeout** (at `06eb83531`). A transaction held `identity_access_tokens` open for
   20 s while an ALTER of it ran:
   - On the `MIGRATE=1` connection (`lock_wait_timeout` 5): the ALTER gave up
     after 5.0 s, and a SELECT queued behind it returned after 4.9 s.
   - With the server's default: the ALTER and the queued SELECT both waited
     18 s, until the transaction ended.

   The app connection still reports the server's 31536000.

Not checked here: a Bearer request end to end over HTTP (the checks call the
lookups the Bearer path calls), and production's own table definitions (`SHOW
CREATE TABLE` on the primary would confirm they match `main`'s `schema.rb`).

## Re-verification, refresh_token kept until D3

#3192 (head `617edb87b`) no longer drops `identity_access_tokens.refresh_token`
in #10. It ignores the column, and #9 empties it; D3 (#3203) drops it beside
`token`. On thelio against dedicated MySQL 8.4 containers, at the merge of
#3191 (`9ac2cb078`): SaaS (MySQL) 2313 tests, OSS (SQLite) 2143, OSS (MySQL)
2143, **0 failures, 0 errors**; rubocop clean. The migrated schema matches the
committed `db/schema.rb` up to column order. The restacked #3206, #3204, #3205,
D2 and D3 each pass all three suites, with 0 failures and 0 errors.

## Before beta boots #3192

`OAUTH_TOKEN_PEPPER` must exist in 1Password (account
`23QPQDKZC5BKBIIG7UGT5GR5RM`, vault **Deploy**, item **Fizzy**) as two fields:

- `Production/OAUTH_TOKEN_PEPPER`, read by production and by beta
  (`saas/.kamal/secrets.beta`, which `secrets.beta1`–`4` link to, fetches the
  Production field), since beta writes digests into production's database.
  There is no Beta field to keep in step.
- `Staging/OAUTH_TOKEN_PEPPER`, staging's own (its own database).

Each at least 32 characters (`bin/rails secret`). Without it `kamal secrets
fetch` fails for that destination, and a container started without it refuses
to boot (`TokenDigester::MissingPepper`). It must never change afterwards. Run
#8 to #10 in the same session as #1 to #7, and run them from this branch (which
carries #3192), so no prefixed personal access token is written without a
digest.
