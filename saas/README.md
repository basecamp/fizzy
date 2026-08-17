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

In SaaS mode `bin/dev` boots a cell beside the server, through `Procfile.dev` and foreman. The cell runs uncontainerized, because a container cannot receive a file descriptor on macOS — Docker runs a Linux VM there and `SCM_RIGHTS` has nothing meaningful to hand across two kernels.

```sh
bin/dev            # the cell boots and /hotcellz answers; conversions still run in the app
bin/dev --hotcell  # attachment processing goes to the cell
```

`/hotcellz` says whether the cell is reachable. It asks the control socket only — `describe` and `metrics`, which the supervisor answers inline with no fork — and replies `OK` or `FAIL` with a 200 or a 503. It is unauthenticated so a monitor can poll it, and it says nothing else, because a stranger has no business knowing the cell's inventory or how loaded it is.

`/hotcellz/test` is staff-only and returns the full diagnosis as JSON, including two round trips over the work socket, the socket that carries real files. The two prove different halves of it: `example.echo` reads its descriptor directly, while `example.reopen` re-opens it by name, which is what every operation that hands a tool a filename does. A cell whose group is wrong answers echo perfectly and fails reopen — so echo alone will tell you a broken cell is healthy. Each round trip forks a worker, which is why this is the half behind authentication.

**A monitor therefore cannot see a broken work socket.** Only the round trips can, and they are staff-only. That is deliberate: it is a configuration error rather than something that degrades on its own, so run `/hotcellz/test` — or the `Cell.diagnostics(work: true)` runner — by hand whenever the configuration changes.

Because the dev cell shells out to your laptop rather than to the image, every tool in `saas/hotcell/Dockerfile` needs a host equivalent. `bin/setup` installs them; if you add a tool to the image, add it to `.mise.toml` and the `Brewfile` too, or that operation will fail in development only.

### The switches

| variable | what it does | where it lives |
| --- | --- | --- |
| `HOTCELL_ROOT` | Registers the cell. Metrics, `describe`, the healthcheck and `/hotcellz` answer, and every conversion still runs in the app. | `saas/config/deploy.yml` |
| `HOTCELL_GROUP` | The gid the app and the cell share, so the cell can open a file the app hands it by name. Must match the `group-add` on the app's roles and the cell's own gid. Unset in development, where both sides run as one user. | `saas/config/deploy.yml` |
| `HOTCELL_ACTIVE_STORAGE` | Moves the work. A comma-separated list of `images`, `pdfs`, `media`, or `all`. | each `saas/config/deploy.<destination>.yml` |

Registering and moving work are separate questions, and the second is a list because the rollout moves
operations in groups. `images` carries the image analyzer along with the transformer whether or not you
ask: Rails' image analyzers test `variant_processor == :vips`, so pointing the transformer at a class makes
them decline and blobs get marked analyzed with no dimensions.

The first two are the same everywhere and belong in the base file. **`HOTCELL_ACTIVE_STORAGE` belongs in
the destination files**, because how far a destination has rolled out is a per-destination decision — in
the base it moves every destination at once. A destination naming no list keeps its cell registered and
idle, which is where one that has not started should be.

An unknown group name raises at boot rather than meaning "off".

### Building and shipping the image

Kamal builds app images and not accessory images, so the cell's image has its own two scripts. They are separate so that building can happen anywhere and publishing is deliberate.

```sh
saas/hotcell/bin/build                        # locks the revision, builds, pins deploy.yml to the tag
saas/hotcell/bin/build --platform=linux/amd64 # what the hosts run
saas/hotcell/bin/push                         # pushes that tag to the registry
```

**The tag is a content hash**, the first 12 characters of a SHA-256 over the `Dockerfile`, `Gemfile`,
`Gemfile.lock`, `config.rb` and `operations/*.rb` — see `bin/image`. Not a git revision: the commit that
bumps the gem and pins the result could never name itself, because amending it changed the SHA the pin was
meant to hold. Identical bytes give an identical tag, and changing something the image does not contain
leaves it alone. `saas/test/lib/hotcell_accessory_test.rb` holds the pin in `deploy.yml` equal to what the
tree builds, so a stale pin fails in CI.

**`build` locks the cell's `Gemfile.lock` to the hotcell revision in the app's `Gemfile.saas.lock`**,
writing it if the two differ, and then builds. The app's lockfile is the source of truth: a client and
server one revision apart is a `protocol` failure on every request. So move the gem in the application
first, then build.

**`build` also writes the pin in `saas/config/deploy.yml`**, and it belongs there rather than in `push`:
the tag is a hash of the tree's contents, so the pin has to land in the same commit as the contents that
produced it. `push` happens after that commit, so pinning there would leave every commit holding a stale
pin. Both lockfiles, the operations, and the pin go in one change.

Tags are immutable and there is no `latest`: a deploy does not update an accessory, so `bin/kamal accessory reboot hotcell -d <destination>` pulls whatever the tag names at that moment. A moving tag would make what a host runs depend on when it last rebooted.

## Environments

Fizzy is deployed with [Kamal](https://kamal-deploy.org/). You'll need to have the 1Password CLI set up in order to access the secrets that are used when deploying. Provided you have that, it should be as simple as `bin/kamal deploy` to the correct environment.

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
