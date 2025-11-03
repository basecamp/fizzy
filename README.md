# Fizzy

## Setting up for development

First get everything installed and configured with:

    bin/setup

If you'd like to load fixtures:

    bin/rails db:fixtures:load

And then run the development server:

    bin/dev

You'll be able to access the app in development at http://development-tenant.fizzy.localhost:3006

## Running tests

For fast feedback loops, unit tests can be run with:

    bin/rails test

The full continuous integration tests can be run with:

    bin/ci

### Tests

### Outbound Emails

#### Development

You can view email previews at http://fizzy.localhost:3006/rails/mailers.

You can enable or disable [`letter_opener`](https://github.com/ryanb/letter_opener) to
open sent emails automatically with:

    bin/rails dev:email

Under the hood, this will create or remove `tmp/email-dev.txt`.

## Environments

Fizzy is deployed with Kamal. You'll need to have the 1Password CLI set up in order to access the secrets that are used when deploying. Provided you have that, it should be as simple as `bin/kamal deploy` to the correct environment.

### Beta

Beta is primarily intended for testing product features.

Beta tenant is:

- https://fizzy-beta.37signals.com

This environment uses local disk for Active Storage.


### Staging

Staging is primarily intended for testing infrastructure changes.

- https://fizzy.37signals-staging.com/

This environment uses a FlashBlade bucket for blob storage, and shares nothing with Production. We may periodically copy data here from production.


### Production

- https://app.box-car.com/

This environment uses a FlashBlade bucket for blob storage.
