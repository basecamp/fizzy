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

Then you can work do [Fizzy development as usual](https://github.com/basecamp/fizzy).

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

## Environments

Fizzy is deployed with [Kamal](https://kamal-deploy.org/). You'll need to have the 1Password CLI set up in order to access the secrets that are used when deploying. Provided you have that, it should be as simple as `bin/kamal deploy` to the correct environment.

## Handbook

See the [Fizzy handbook](https://handbooks.37signals.works/18/fizzy) for runbooks and more.

### Production

- https://app.fizzy.do/

This environment uses a FlashBlade bucket for blob storage.

### Beta

Beta is primarily intended for testing product features. It uses the same production database and Active Storage configuration.

There are 4 beta environments:

- https://beta1.fizzy-beta.com
- https://beta2.fizzy-beta.com
- https://beta3.fizzy-beta.com
- https://beta4.fizzy-beta.com

Deploy with: `bin/kamal deploy -d beta1` (or `-d beta2`, `-d beta3`, `-d beta4`)

### Staging

Staging is primarily intended for testing infrastructure changes. It uses production-like but separate database and Active Storage configurations.

- https://app.fizzy-staging.com/

## License

fizzy-saas is released under the [O'Saasy License](LICENSE.md).
