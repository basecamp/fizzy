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

`/hotcellz` says whether the cell is reachable. It asks the control socket only — `describe` and `metrics`, which the supervisor answers inline with no fork — and replies `OK` or `FAIL` with a 200 or a 503. It is unauthenticated so a monitor can poll it, and it says nothing else, because a stranger has no business knowing the cell's inventory or how loaded it is.

`/hotcellz/test` is staff-only and returns the full diagnosis as JSON, including two round trips over the work socket, the socket that carries real files. The two prove different halves of it: `example.echo` reads its descriptor directly, while `example.reopen` re-opens it by name, which is what every operation that hands a tool a filename does. A cell whose group is wrong answers echo perfectly and fails reopen — so echo alone will tell you a broken cell is healthy. Each round trip forks a worker, which is why this is the half behind authentication.

**A monitor therefore cannot see a broken work socket.** Only the round trips can, and they are staff-only. That is deliberate: it is a configuration error rather than something that degrades on its own, so run `/hotcellz/test` — or the `Cell.diagnostics(work: true)` runner — by hand whenever the configuration changes.

Because the dev cell shells out to your laptop rather than to the image, every tool in `saas/hotcell/Dockerfile` needs a host equivalent. `bin/setup` installs them; if you add a tool to the image, add it to `.mise.toml` and the `Brewfile` too, or that operation will fail in development only.

### The switches

| variable | what it does | where it lives |
| --- | --- | --- |
| `HOTCELL_ROOT` | Registers the cell, which then carries every conversion. Unset, everything runs in the app. | `saas/config/deploy.yml` |
| `HOTCELL_GROUP` | The gid the app and the cell share, so the cell can open a file the app hands it by name. Must match the `group-add` on the app's roles and the cell's own gid. Unset in development, where both sides run as one user. | `saas/config/deploy.yml` |

### Deploying

```sh
bin/deploy <destination>
```

That is the whole deploy. It brings the destination's hotcell accessory onto the image this commit pins, then runs `bin/kamal deploy -d <destination>`. It takes nothing but the destination. For any other kamal argument run `bin/kamal deploy` yourself, with `SKIP_HOTCELL_CHECKS=1` if you mean to deploy over a broken cell.

Underneath, `bin/deploy` forwards to `saas/bin/deploy`, which drives three scripts in `saas/hotcell/bin/`:

| script | what it does |
| --- | --- |
| `check <destination>` | Is the pinned image in the registry, and is the accessory on one host of `<destination>` running it? The exit status names the fix: 2 build and push, 3 reboot, 1 the check could not tell. |
| `build [--platform=linux/amd64]` | Locks `saas/hotcell/Gemfile.lock` to the hotcell version in `Gemfile.saas.lock`, builds the image, and pins `saas/config/deploy.yml` to its tag. |
| `push` | Pushes the built tag to the registry. |

`bin/deploy` runs `check`, applies the fix its status names (`build --platform=linux/amd64` and `push`, then `bin/kamal accessory reboot hotcell`; or the reboot alone), runs `check` again, and only then deploys the app. `saas/.kamal/hooks/pre-deploy` runs the same `check` before a direct `bin/kamal deploy`, so a stale cell stops that deploy too, with the fix spelled out.

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

4. Deploy each destination. `bin/deploy` sees the new pin is not in the registry, pushes it, reboots the cell, and deploys the app:

   ```sh
   bin/deploy <destination>
   ```

5. Verify the destination: `/hotcellz` answers `OK`, `/hotcellz/test` (staff-only) passes all four checks, `hotcell_up == 1` for every host in Prometheus, and no `WARN`/`ERROR` lines in Loki under `{service_name="hotcell"}`.

`build` is the one step by hand, because the pin it writes belongs in your commit: the tag is a content hash and the commit that changes the contents has to carry it. `bin/deploy` refuses to push a pin that is not committed.

#### Why it is built this way

**The tag is a content hash**, the first 12 characters of a SHA-256 over the `Dockerfile`, `Gemfile`, `Gemfile.lock`, `config.rb` and `operations/*.rb` (see `saas/hotcell/bin/image`). Not a git revision: the commit that bumps the gem and pins the result could never name itself, because amending it changed the SHA the pin was meant to hold. Identical bytes give an identical tag, and changing something the image does not contain leaves it alone.

**`build` locks the cell's `Gemfile.lock` to the app's hotcell version** because a client and server one version apart is a `protocol` failure on every request. The app's lockfile is the source of truth: move the gem in the application first, then build.

**Tags are immutable and there is no `latest`.** A deploy does not update an accessory; `kamal accessory reboot` pulls whatever the tag names at that moment, and a moving tag would make what a host runs depend on when it last rebooted. That is also why a deploy that only bumps the gem still has to reboot the cell, and why `bin/deploy` does it for you.

## Environments

Fizzy is deployed with [Kamal](https://kamal-deploy.org/). You'll need to have the 1Password CLI set up in order to access the secrets that are used when deploying. Provided you have that, it should be as simple as `bin/deploy <destination>`.

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

## License

fizzy-saas is released under the [O'Saasy License](LICENSE.md).
