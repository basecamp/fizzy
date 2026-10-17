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
| #2296 | `oauth` | `76024c1e2f37` |
| #3080 | `oauth-dcr-https` | `13b082285071` |
| #3081 | `oauth-refresh-tokens` | `243fd48a6045` |
| #3082 | `oauth-confidential-clients` | `dc2d791ecc29` |
| #3158 | `oauth-bearer-challenge` | `cb10c0cf62c7` |
| #3160 | `oauth-refresh-replay` | `3a6626e95a57` |
| #3161 | `oauth-grant-idle-expiry` | `7e4072cc3f76` |
| #3159 | `oauth-client-sweep` | `6ff3be4b0fbc` |
| #3163 | `oauth-token-prefixes` | `313046c981c4` |
| #3169 | `oauth-delegate-resources` | `aef9fb5fb895` |
| #3192 | `oauth-token-digests` | `1ef16f3d245e` |
| #3191 | `test/pin-shipped-client-auth` | `98572aaaf` |

One textual conflict, merging #3161 after its sibling #3158, both appending
tests to the end of `test/models/identity/access_token_test.rb`: kept both
sides (#3158's `find_honored` tests, then #3161's daylight-saving idle-limit
test). Merging #3192 after #3158 conflicted in `app/models/identity/access_token.rb`
and its test: #3158 replaced `find_permissable` with `find_honored` beside
#3160, so #3192 never saw it. The merge keeps `find_honored` and has it find by
digest (`active.find_by_raw_token(token)`), and #3192's tests call it. The same
resolution is needed wherever #3158 and #3192 first meet on `main`.
Nothing else conflicted.

Beyond the merges, one commit of the branch's own, `saas/config/deploy.beta.yml`
setting the web role's `cmd` so a beta boot does not migrate (see "Deploying
without migrating" below), and this file.

## Beta shares the production database

`saas/config/database.yml` ends `beta: *production`, and `deploy.beta.yml` points
beta at `fizzy-mysql-primary`. **Migrating on beta1 is migrating
`fizzy_production`.** Every migration below is additive (new tables, new
nullable columns, new indexes), so `main`, running in production, keeps working
against the migrated schema: it never reads the new columns, and its inserts
leave them NULL.

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
| 9 | `20261015120100_backfill_token_digests.rb` | #3192 | **Data only, no DDL.** Refuses duplicate `token`s first. Then one `UPDATE … WHERE id = ?` per row: `token_digest` for every token (OAuth rows also get `token` NULLed), `refresh_token_digest` and `client_secret_digest` where those columns still exist. `updated_at` doesn't move. `disable_ddl_transaction!`, batches of 500. `down` is a no-op | `identity_access_tokens` | Row locks only, ~3,500 single-row updates on the primary key, a few seconds |
| 10 | `20261015120200_drop_plaintext_oauth_credentials.rb` | #3192 | Drop `identity_access_tokens.refresh_token` and its unique index. Drop `oauth_clients.client_secret`. Drop and recreate `oauth_retired_refresh_tokens` keyed by digest, with `successor_payload` text | `identity_access_tokens`, plus the empty `oauth_*` tables | DROP INDEX and DROP COLUMN are online. The `oauth_*` tables are empty in production |

#1 to #8 and #10 are reversible, so each has a working `down`; #9's `down` is a
no-op. All ten are portable: they ran up, down and up again on
SQLite and on MySQL 8.4 (see "Verification").

### The lock that matters

At these sizes the copy work is nothing. What can hurt is the metadata lock:
every ALTER briefly takes an exclusive MDL on its table, waits for open
transactions on that table to finish first, and while it waits every new query
on the table queues behind it. `identity_access_tokens` is read on every API
request that sends a Bearer token. The `MIGRATE=1` connection has no
`max_execution_time`, and nothing sets `lock_wait_timeout`, so a stuck ALTER
waits for as long as the blocking transaction lives. Check for long-running
transactions just before (`information_schema.innodb_trx`), and if a step sits
for more than a few seconds, cancel it rather than let the queue build.

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
Then restart the app so every process reloads its column information:
`bin/kamal app boot -d beta1`. The web container keeps the non-migrating
command; nothing is pending anyway.

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
```

This drops `oauth_clients`, `oauth_retired_refresh_tokens` and the new columns,
along with anything beta wrote to them. Personal access tokens keep their
plaintext throughout, so `main` keeps authenticating them. Undo only once nothing is running this
branch's code: `main` doesn't care either way.

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

On thelio against a dedicated MySQL 8.4 container, at the merge of #3191:

- Migration round trip on MySQL (OSS), from `main`'s schema loaded by `main`'s
  code: all ten up, all ten down newest first, all ten up. The dump differs
  from the committed `db/schema.rb` in column order only.
- SaaS (MySQL) 2299 tests, OSS (SQLite) 2129, OSS (MySQL) 2129: the same **2
  failures** in each, #3191's two pins against #3158 (decision D6 below), and
  nothing else.

## Before beta boots #3192

`TOKEN_DIGEST_PEPPER` must exist in 1Password, Deploy/Fizzy vault, on the
**Production** item (beta's `saas/.kamal/secrets.beta` reads it from there) and
on the **Staging** item. Without it `kamal secrets fetch` fails and the app
refuses to boot. It must never change afterwards. Run #8 to #10 in the same
session as #1 to #7, and run them from this branch (which carries #3192), so no
prefixed personal access token is written without a digest.
