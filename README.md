# Fizzy

This is the source code of [Fizzy](https://fizzy.do/), the Kanban tracking tool for issues and ideas by [37signals](https://37signals.com).

## Deploying Fizzy

If you'd like to run Fizzy on your own server, we recommend deploying it with [Kamal](https://kamal-deploy.org/).
Kamal makes it easier to set up a bare server, copy the application to it, and manage the configuration settings that it uses.

(Kamal is also what we use to deploy Fizzy at 37signals. If you're curious about what our deployment configuration looks like, you can find it inside [`fizzy-saas`](https://github.com/basecamp/fizzy-saas).)

This repo contains a starter deployment file that you can modify for your own specific use. That file lives at [config/deploy.yml](config/deploy.yml), which is the default place where Kamal will look for it.

The steps to configure your very own Fizzy are:

1. Fork the repo
2. Edit few things in config/deploy.yml, .kamal/secrets, and config/environments/production.rb
3. Run `kamal setup` to do your first deploy.

We'll go through each of these in turn.

### Fork the repo

To make it easy to customise Fizzy's settings for your own instance, you should start by creating your own GitHub fork of the repo.
That allows you to commit your changes, and track them over time.
You can always re-sync your fork to pick up new changes from the main repo over time.

Once you've got your fork ready, run `bin/setup` from within it, to make sure everything is installed.

### Editing the configuration

The config/deploy.yml has been mostly set up for you, but you'll need to fill out some sections that are specific to your instance.
To get started, the parts you need to change are all in the "About your deployment" section.
We've added comments to that file to highlight what each setting needs to be, but the main ones are:

- `servers/web`: Enter the hostname of the server you're deploying to here. This should be an address that you can access via `ssh`.
- `ssh/user`: If you access your server a `root` you can leave this alone; if you use a different user, set it here.
- `proxy/ssl` and `proxy/host`: Kamal can set up SSL certificates for you automatically. To enable that, set the hostname again as `host`. If you don't want SSL for some reason, you can set `ssl: false` to turn it off.
- `env/clear/MAILER_FROM_ADDRESS`: This is the email address that Fizzy will send emails from. It should usually be an address from the same domain where you're running Fizzy.

Fizzy also requires a few environment variables to be set up, some of which contain secrets.
The simplest way to do this is to put them in a file called `.kamal/secrets`.
Because this file will contain secret credentials, it's important that you DON'T CHECK THIS FILE INTO YOUR REPO! You can add the filename to `.gitignore` to ensure you don't commit this file accidentally.

If you use a password manager like 1Password, you can also opt to keep your secrets there instead.
Refer to the [Kamal documentation](https://kamal-deploy.org/docs/configuration/environment-variables/#secrets) for more information about how to do that.

To store your secrets, create the file `.kamal/secrets` and enter something like the following:

```ini
SECRET_KEY_BASE=12345
VAPID_PUBLIC_KEY=something
VAPID_PRIVATE_KEY=somethingelse
SMTP_USERNAME=email-provider-username
SMTP_PASSWORD=email-provider-password
```

The values you enter here will be specific to you, and you can get or create them as follows:

- `SECRET_KEY_BASE` should be a long, random secret. You can run `bin/rails secret` to create a suitable value for this.
- `VAPID_PUBLIC_KEY` & `VAPID_PRIVATE_KEY` are a pair of credentials that are used for sending notifications. You can create your own keys by starting a development console with:

  ```sh
  bin/rails c
  ```

  And then run the following to create a new pair of keys:

  ```ruby
  vapid_key = WebPush.generate_key

  puts "VAPID_PRIVATE_KEY=#{vapid_key.private_key}"
  puts "VAPID_PUBLIC_KEY=#{vapid_key.public_key}"
  ```

- `SMTP_USERNAME`/`SMTP_PASSWORD` are credentials you should get from your email provider.

Lastly, you'll need to set up the rest of your email configuration in `config/environments/production.rb`. There is an example configuration in comments at the top of that file. The actual settings you use here will depend on your email provider, but in most cases will look similar to that section, so you can uncomment it and edit to suit. Note that it will use the `SMTP_USERNAME` and `SMTP_PASSWORD` values you entered in your secrets.

Once you've made all those changes, commit them to your fork so they're saved.

### Deploy Fizzy!

You can now do your first deploy by running:

```sh
bin/kamal setup
```

This will set up Docker (if needed), build your Fizzy app container, configure it, and start it running.

After the first deploy is done, any subsequent steps won't need to do that initial setup. So for future deploys you can just run:

```sh
bin/kamal deploy
```

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

To login, enter `david@example.com` and grab the verification code from the browser console to sign in.

### Web Push Notifications

Fizzy uses VAPID (Voluntary Application Server Identification) keys to send browser push notifications. For notifications to work in development you'll need to generate a key pair and set these environment variables:

- `VAPID_PRIVATE_KEY`
- `VAPID_PUBLIC_KEY`

Generate them with the `web-push` gem:

```ruby
vapid_key = WebPush.generate_key

puts "VAPID_PRIVATE_KEY=#{vapid_key.private_key}"
puts "VAPID_PUBLIC_KEY=#{vapid_key.public_key}"
```

### Running tests

For fast feedback loops, unit tests can be run with:

```sh
bin/rails test
```

The full continuous integration tests can be run with:

```sh
bin/ci
```

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

```sh
bin/rails dev:email
```

Under the hood, this will create or remove `tmp/email-dev.txt`.

## SaaS gem

37signals bundles Fizzy with [`fizzy-saas`](https://github.com/basecamp/fizzy-saas), a companion gem that links Fizzy with our billing system and contains our production setup.

This gem depends on some private git repositories and it is not meant to be used by third parties. But we hope it can serve as inspiration for anyone wanting to run fizzy on their own infrastructure.

## Contributing

We welcome contributions! Please read our [style guide](STYLE.md) before submitting code.

## License

Fizzy is released under the [O'Saasy License](LICENSE.md).
