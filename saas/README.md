This is a Rails engine that [37signals](https://37signals.com/) bundles with [Fizzy](https://github.com/basecamp/fizzy) to offer the hosted version at https://fizzy.do.

## Development

To make Fizzy run in SaaS mode, run this in the terminal:

```ruby
bin/rails saas:enable
```

To go back to open source mode:

```ruby
bin/rails saas:disable
```

Then you can do [Fizzy development as usual](https://github.com/basecamp/fizzy).

## How to update Fizzy

After making changes to this gem, you need to update Fizzy to pick up the changes:

```ruby
BUNDLE_GEMFILE=Gemfile.saas bundle update --conservative fizzy-saas
```

## Working with Stripe

The first time, you need to:

1. Install Stripe CLI: https://stripe.com/docs/stripe-cli
2. Run `stripe login` and authorize the environment `37signals Development`

Then, for working on the Stripe integration locally, you need to run this script to start the tunneling and set the environment variables:

```sh
eval "$(BUNDLE_GEMFILE=Gemfile.saas bundle exec stripe-dev)"
bin/dev # You need to start the dev server in the same terminal session
```

This will ask for your 1password authorization to read and set the environment variables that Stripe needs.

### Stripe environments

* [Development](https://dashboard.stripe.com/acct_1SdTFtRus34tgjsJ/test/dashboard)
* [Staging](https://dashboard.stripe.com/acct_1SdTbuRvb8txnPBR/test/dashboard)
* [Production](https://dashboard.stripe.com/acct_1SNy97RwChFE4it8/dashboard)

## Working with Push Notifications

To test native push notifications (APNs and FCM) locally, start the dev server with the `--push` flag:

```sh
bin/dev --push
```

This will ask for your 1Password authorization to fetch the push credentials. Note that this loads the **production** APNs and FCM credentials into your environment.

## Attachment processing in a hotcell cell

Image variants, blob analysis and PDF and video previews can run in an unprivileged sibling container with no network, instead of in the app process beside the database credentials. The cell lives in `saas/hotcell/` — its `Dockerfile`, its own `Gemfile`, its limits in `config.rb`, and the operations it serves.

### Running it

In SaaS mode `bin/dev` boots a cell beside the server, through `saas/Procfile.dev` and foreman. The cell runs uncontainerized, because a container cannot receive a file descriptor on macOS — Docker runs a Linux VM there and `SCM_RIGHTS` has nothing meaningful to hand across two kernels.

```sh
bin/dev            # the cell boots and carries attachment processing, as in production
```

`/hotcellz` says whether the cell is reachable. Served by the gem's `HotCell::HealthController`, it asks the control socket only — `describe` and `metrics`, which the supervisor answers inline with no fork — and replies `OK` or `FAIL` with a 200 or a 503. It is unauthenticated so a monitor can poll it, and it says nothing else, because a stranger has no business knowing the cell's inventory or how loaded it is.

`/hotcellz/test` is the gem's `HotCell::DiagnosticsController`, staff-only because its parent is `AdminController`. It returns the full diagnosis as JSON, including two round trips over the work socket, the socket that carries real files. The two prove different halves of it: `health.echo` reads its descriptor directly, while `health.reopen` re-opens it by name, which is what every operation that hands a tool a filename does. A cell whose group is wrong answers echo perfectly and fails reopen — so echo alone will tell you a broken cell is healthy. Each round trip forks a worker, which is why this is the half behind authentication.

**A monitor therefore cannot see a broken work socket.** Only the round trips can, and they are staff-only. That is deliberate: it is a configuration error rather than something that degrades on its own, so run `/hotcellz/test` — or `HotCell.diagnose(work: true).as_json` in a console — by hand whenever the configuration changes.

Because the dev cell shells out to your laptop rather than to the image, every tool in `saas/hotcell/Dockerfile` needs a host equivalent. `bin/setup` installs them; if you add a tool to the image, add it to `.mise.toml` and the `Brewfile` too, or that operation will fail in development only.

### The switches

| variable | what it does | where it lives |
| --- | --- | --- |
| `HOTCELL_ROOT` | Registers the cell, which then carries every conversion. Unset, everything runs in the app. | `saas/config/deploy.yml` |
| `HOTCELL_GROUP` | The gid the app and the cell share, so the cell can open a file the app hands it by name. Must match the `group-add` on the app's roles and the cell's own gid. Unset in development, where both sides run as one user. | `saas/config/deploy.yml` |

### Deploying

```sh
bin/kamal deploy -d <destination>
```

That deploys both containers the app is made of: the app itself, and the hotcell cell that does its attachment processing, which Kamal treats as an accessory with its own image and its own lifecycle. Two hooks keep the cell in step, so you never have to think about it:

- `saas/.kamal/hooks/pre-build` runs `saas/hotcell/bin/check --publish`: if the registry lacks the cell image this commit pins, it builds it for the hosts' platform and pushes it. Before the deploy lock, no ssh.
- `saas/.kamal/hooks/pre-deploy` runs `saas/hotcell/bin/check --reboot`: if a host is running anything but the pinned image, it reboots the accessory there. Under the lock, right before the app boots.

Both take the pin from the commit being deployed (`KAMAL_VERSION`), so `bin/kamal rollback` puts the cell back too, and both honor `--hosts` and `--roles`, so a deploy to two hosts reboots the cell on those two. `SKIP_HOTCELL_CHECKS=1` skips both, for deploying over a broken cell on purpose.

By hand, `saas/hotcell/bin/check <destination>` reports the cell's state and what would fix it, and `--apply` fixes it. The exit status names the fix: 2 build and push, 3 reboot, 1 the check could not tell. The other two scripts in `saas/hotcell/bin/` are `build [--platform=linux/amd64]`, which locks `saas/hotcell/Gemfile.lock` to the hotcell version in `Gemfile.saas.lock`, builds the image, and pins `saas/config/deploy.yml` to its tag, and `push`, which pushes the built tag to the registry.

The check fails rather than guesses when it cannot answer: docker not logged in, ssh not getting through. Telling someone to rebuild a published image because `docker manifest inspect` could not authenticate is the failure mode that costs the most.

### Changing the cell

Anything under `saas/hotcell/` that the image copies in, or a hotcell gem moving in `Gemfile.saas.lock`, means a new image. CI tells you when you owe one: `saas/test/lib/hotcell_accessory_test.rb` fails if the pin in `deploy.yml` no longer matches what the tree builds.

1. Build, which pins `saas/config/deploy.yml`:

   ```sh
   saas/hotcell/bin/build --platform=linux/amd64
   ```

2. Run the tests:

   ```sh
   bin/rails test saas/test/lib/hotcell_accessory_test.rb
   ```

3. Commit everything together: both lockfiles, the pin, and whatever changed under `saas/hotcell/`.

4. Deploy each destination. The hooks see the new pin is not in the registry, push it, reboot the cell, and deploy the app:

   ```sh
   bin/kamal deploy -d <destination>
   ```

5. Verify the destination: `/hotcellz` answers `OK`, `/hotcellz/test` (staff-only) passes all four checks, `hotcell_up == 1` for every host in Prometheus, and no `WARN`/`ERROR` lines in Loki under `{service_name="hotcell"}`.

`build` is the one step by hand, because the pin it writes belongs in your commit: the tag is a content hash and the commit that changes the contents has to carry it. `check --publish` refuses to push a pin that is not committed.

#### Why it is built this way

**The tag is a content hash**, the first 12 characters of a SHA-256 over the `Dockerfile`, `Gemfile`, `Gemfile.lock`, `config.rb` and `operations/*.rb` (see `saas/hotcell/bin/image`). Not a git revision: the commit that bumps the gem and pins the result could never name itself, because amending it changed the SHA the pin was meant to hold. Identical bytes give an identical tag, and changing something the image does not contain leaves it alone.

**`build` locks the cell's `Gemfile.lock` to the app's hotcell version** because a client and server one version apart is a `protocol` failure on every request. The app's lockfile is the source of truth: move the gem in the application first, then build.

**Tags are immutable and there is no `latest`.** A deploy does not update an accessory; `kamal accessory reboot` pulls whatever the tag names at that moment, and a moving tag would make what a host runs depend on when it last rebooted. That is also why a deploy that only bumps the gem still has to reboot the cell, and why the `pre-deploy` hook does it for you.

## Environments

Fizzy is deployed with [Kamal](https://kamal-deploy.org/). You'll need to have the 1Password CLI set up in order to access the secrets that are used when deploying. Provided you have that, it should be as simple as `bin/kamal deploy -d <destination>`.

## Handbook

See the [Fizzy handbook](https://handbooks.37signals.works/18/fizzy) for runbooks and more.

### Production

- https://app.fizzy.do/

This environment uses a FlashBlade bucket for blob storage.

### Beta

Beta is primarily intended for testing product features. It uses the same production database and Active Storage configuration.

There is 1 beta environment:

- https://beta1.fizzy-beta.com

Deploy with: `bin/kamal deploy -d beta1`

### Staging

Staging is primarily intended for testing infrastructure changes. It uses production-like but separate database and Active Storage configurations.

- https://app.fizzy-staging.com/

## Job memory diagnostics

Set `LOG_JOB_MEMORY=true` in a jobs role's deployment environment to add `performance.memory` and `performance.gc` to its structured job log lines. Beta jobs enable it. Changing it takes a deploy.

Following bc3's `Memory::Stats`, each line carries totals and deltas for RSS in bytes, Ruby heap slots, allocated objects, collection counts, old-generation malloc growth and GC time in milliseconds, plus the last major collection's trigger. The counters are process-wide, and each jobs process runs several threads (`config/queue.yml`), so a delta covers every job that overlapped this one, not this job alone. Correlate lines by process ID to follow one process's growth over time. RSS includes shared pages, so summing worker RSS overstates host memory use. These are samples at job boundaries, not peaks, and a process killed during a job logs nothing for it.

## Maintenance mode

To take production offline for maintenance, run `kamal-proxy stop` on the load balancers via `knife ssh`:

```bash
knife ssh 'hostname:fizzy-lb-*' "sudo docker exec fizzy-load-balancer kamal-proxy stop fizzy --message='Sorry! Fizzy is undergoing some maintenance and will be back shortly.'"
```

Verify maintenance is enabled by visiting https://app.fizzy.do/.

To lift maintenance mode:

```bash
knife ssh 'hostname:fizzy-lb-*' 'sudo docker exec fizzy-load-balancer kamal-proxy resume fizzy'
```

## Override record: CIMD open-tier light-up (2026-11-24)

**Status:** `OAUTH_CIMD_OPEN_REGISTRATION: "true"` in `saas/config/deploy.production.yml` (fizzy#3336), on the dark code from fizzy#3335. beta1 already set it for previewers (`saas/config/deploy.beta.yml`), on production's database, behind `CONNECTED_APPS_PREVIEW`. Production now sets it for everyone. Staging and the other betas don't.

**The decision.** Jeremy Daer, operator, decided on 2026-11-24, in the session that directed this work:

- Drop the per-domain registration quota table ("Drop table; sweep + blocklist").
- Switch the open tier on in production under a dated override record in the same form as Basecamp's open-tier record.
- Rely on the guards below in place of the quota.

**Why there's no domain quota.** Basecamp caps new open-tier clients at 25 per registrable domain per 30 days. Three things argued against porting that cap:

- **It doesn't stop a determined attacker.** The registrable domain comes from the Public Suffix List with its private section included. So every free project under a hosting suffix (`vercel.app`, `pages.dev`, `netlify.app`, `github.io`) counts as its own domain, with its own allowance.
- **Its refusals were invisible.** A refusal answered as an unknown client and left no trace. A legitimate multi-tenant host's 26th app would fail without anyone noticing.
- **It needed a new table and a migration.** What bounds rows without one is a short sweep and a block list.

**What bounds the open tier instead** (fizzy#3335):

- **FetchLease.** At most 6 fetches in flight per database server, held as MySQL named locks. It answers a retryable 503 when the slots are full or the lock fails.
- **Fetch budgets.** 60 attempts an hour per registrable domain, site-wide. Per person, 6 a minute per URL. They're counted in `Rails.cache` and fail open.
- **The sweep.** Every hour, `Oauth::Client.cleanup` deletes open-tier metadata document clients that hold no access token and haven't been touched in 24 hours. The next authorization provisions the row again from its document.
- **The block list.** `OAUTH_CIMD_BLOCKED_DOMAINS` covers a domain and every host under it, in either tier. It refuses before any fetch, including clients already provisioned, and answers as an unknown client.
- **The per-person cap.** 20 open-tier apps with live grants per identity. Reconnecting an app the person already has is never refused. No production identity holds more than a tenth of the cap.
- **Refusal telemetry.** `oauth_cimd_refusals_total{reason,tier}` counts `blocked_domain`, `budget`, `grant_cap`, `lease` and `bulkhead`. Each refusal is also an `oauth.client_metadata.refused` audit event naming its registrable domain.
- **The consent warning.** Consent and Connected apps say we don't know the developer.

**What this record accepts without checking it.** None of these ran for Fizzy before this deploy:

1. **Puma headroom.** No per-site read was taken of busy threads against workers. The open tier can add up to 6 concurrent fetches per database server it locks on (see 4). Each fetch holds a Puma thread for at most the fetcher's 3-second deadline.
2. **Recovery of the lease backend across a failover.** For Fizzy that's the MySQL primary rather than a Redis Sentinel, and the lease was never exercised across a promotion. Acquisition fails closed: if the lock can't be taken, the fetch is refused with a 503. Losing the lock mid-fetch is different. A fetch already admitted runs to its 3-second deadline, while a failover that drops its lock lets new fetches be admitted alongside it. For the length of one deadline, in-flight fetches can exceed 6, by up to the number of holders that crossed the failover. That overlap is bounded, not unbounded.
3. **One shared lease pool.** Lock names carry the environment and database, but whether pools are isolated was never checked against the live servers.
4. **The lease against a replica.** `GET_LOCK` is a `SELECT`, so a consent page rendered on a replica takes its lock there, and the authorization POST takes its lock on the primary. That makes the bound 6 per database server rather than 6 per install. It's covered by tests on a single MySQL server and was never run against a real replica.

**Still open.** A client kept by a live grant stays as long as the grant does, as in every tier. The sweep takes open-tier clients that hold no access token once they've been idle a day, which includes clients consented to but never redeemed, and disconnected ones. The cap counts live grants per identity, not per account or per domain, and identities are cheap to make, so an attacker with many identities can keep that many times 20 rows alive. There's no alert on the open-tier creation rate yet. For now, detection means watching `oauth_cimd_refusals_total` and `oauth_cimd_clients_created_total{tier="open"}`.

**Rollback.**

- **To stop one domain:** name it in `OAUTH_CIMD_BLOCKED_DOMAINS` in `saas/config/deploy.production.yml`, then deploy.
- **To stop the whole tier:** delete `OAUTH_CIMD_OPEN_REGISTRATION` there, then deploy. Clients that aren't allowlisted are refused, including ones already provisioned. Grants already issued keep working.
- **For a fetch or SSRF incident:** unset `OAUTH_CIMD_ENABLED`.

## License

fizzy-saas is released under the [O'Saasy License](LICENSE.md).
