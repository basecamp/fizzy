# Fizzy

## Setting up for development

First get everything installed and configured with:

    bin/setup

If you'd like to load seed data:

    bin/rails db:seed

And then run the development server:

    bin/dev

You'll be able to access the app in development at http://development-tenant.fizzy.localhost:3006


## Running tests

For fast feedback loops, unit tests can be run with:

    bin/rails test

The full continuous integration tests can be run with:

    bin/ci


## Deploying

Fizzy is deployed with Kamal. You'll need to have the 1Password CLI set up in order to access the secrets that are used when deploying. Provided you have that, it should be as simple as `bin/kamal deploy` to the correct environment.

### Beta

For beta:

    bin/kamal deploy -d beta

Beta tenant is:

- https://fizzy.37signals.works/


### Production

And for production:

    bin/kamal deploy -d production

Production tenants are:

- https://37s.fizzy.37signals.com/
- https://dev.fizzy.37signals.com/
- https://qa.fizzy.37signals.com/
