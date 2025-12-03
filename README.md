# Fizzy

This is the source code of [Fizzy](https://fizzy.do/), the Kanban tracking tool for issues and ideas by [37signals](https://37signals.com).

## Development

### Setting up

First, get everything installed and configured with:

```sh
bin/setup
bin/setup --reset # Reset the database and seed it
```

And then run the development server:

```sh
bin/dev
```

You'll be able to access the app in development at http://fizzy.localhost:3006.

To login, enter `david@37signals.com` and grab the verification code from the browser console to sign in.

### Running tests

For fast feedback loops, unit tests can be run with:

    bin/rails test

The full continuous integration tests can be run with:

    bin/ci

### Database configuration

Fizzy works with SQLite by default and supports MySQL too. You can switch adapters with the `DATABASE_ADAPTER` environment variable. For example, to develop locally against MySQL:

```sh
DATABASE_ADAPTER=mysql bin/setup --reset
DATABASE_ADAPTER=mysql bin/ci
```

The remote CI pipeline will run tests against both SQLite and MySQL.

### Outbound Emails

You can view email previews at http://fizzy.localhost:3006/rails/mailers.

You can enable or disable [`letter_opener`](https://github.com/ryanb/letter_opener) to open sent emails automatically with:

    bin/rails dev:email

Under the hood, this will create or remove `tmp/email-dev.txt`.

## Deployment

We recommend [Kamal](https://kamal-deploy.org/) for deploying Fizzy. This project comes with a vanilla Rails template. You can find our production setup in [`fizzy-saas`](https://github.com/basecamp/fizzy-saas).

### Web Push Notifications

Fizzy uses VAPID (Voluntary Application Server Identification) keys to send browser push notifications. You'll need to generate a key pair and set these environment variables:

- `VAPID_PRIVATE_KEY`
- `VAPID_PUBLIC_KEY`

Generate them with the `web-push` gem:

```ruby
vapid_key = WebPush.generate_key

puts "VAPID_PRIVATE_KEY=#{vapid_key.private_key}"
puts "VAPID_PUBLIC_KEY=#{vapid_key.public_key}"
```

## SaaS gem

37signals bundles Fizzy with [`fizzy-saas`](https://github.com/basecamp/fizzy-saas), a companion gem that links Fizzy with our billing system and contains our production setup.

This gem depends on some private git repositories and it is not meant to be used by third parties. But we hope it can serve as inspiration for anyone wanting to run fizzy on their own infrastructure.


## Contributing

We welcome contributions! Please read our [style guide](STYLE.md) before submitting code.

## License

Fizzy is released under the [O'Saasy License](LICENSE.md).

