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

To login, enter `david@example.com` and grab the verification code from the browser console to sign in.

### Docker Compose (Alternative Setup)

For easy local and remote development, you can use Docker Compose:

```sh
# Build and start the container
docker-compose up

# Note: If you need to access private GitHub gems, create a token file first:
# echo "your_github_token" > .github_token
# Or set the BUILDKIT_GITHUB_TOKEN environment variable: export BUILDKIT_GITHUB_TOKEN=your_token

# Or run in background
docker-compose up -d

# Stop the container
docker-compose down

# Access Rails console
docker-compose exec app bin/rails console

# Run initial setup (first time only)
docker-compose exec app bin/setup

# View logs
docker-compose logs -f
```

The app will be available at http://localhost:3006. The SQLite databases are persisted in the `storage/` directory, and code changes are hot-reloaded via volume mounts.

#### Remote Development

Docker Compose works great for remote development on a server. After copying the repository to your remote host:

1. **Access the application**: The app will be accessible at `http://your-server-hostname:3006`. To allow access from your server's domain, set the `ALLOWED_HOST_DOMAINS` environment variable (e.g., `ALLOWED_HOST_DOMAINS=example.com,subdomain.example.com`). This can be set in your `docker-compose.yml` or shell environment.

2. **Port forwarding (optional)**: If you prefer to access via localhost, you can use SSH port forwarding:
   ```sh
   # Forward app port
   ssh -L 3006:localhost:3006 user@your-server
   ```
   Then access at http://localhost:3006.

**Note**: If your Gemfile includes private GitHub gems, you need to provide a GitHub token:
- Option 1: Create a `.github_token` file: `echo "your_token" > .github_token`
- Option 2: Set the `BUILDKIT_GITHUB_TOKEN` environment variable: `export BUILDKIT_GITHUB_TOKEN=your_token`
- If neither is provided, create an empty file first: `touch .github_token` (the build will proceed without authentication, but may fail if private gems are required)

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

By default, emails are not sent in development. To preview emails in development, you can use email preview tools. Enable it with:

    bin/rails dev:email

**Local development (non-Docker):**
- When enabled, [`letter_opener`](https://github.com/ryanb/letter_opener) automatically opens sent emails in your browser.

**Docker development:**
- When enabled, [`letter_opener_web`](https://github.com/fgrehm/letter_opener_web) saves emails and makes them accessible via a web interface at http://fizzy.localhost:3006/admin/letter_opener (or your server hostname:3006/admin/letter_opener).

You can toggle email preview on/off by running the command again.

You can also view email previews at http://fizzy.localhost:3006/rails/mailers.

Under the hood, this will create or remove `tmp/email-dev.txt`. The configuration priority is: SMTP (if `SMTP_HOST` env var is set) > letter_opener/letter_opener_web (if `tmp/email-dev.txt` exists) > no delivery (default).

## Deployment

We recommend [Kamal](https://kamal-deploy.org/) for deploying Fizzy. This project comes with a vanilla Rails template. You can find our production setup in [`fizzy-saas`](https://github.com/basecamp/fizzy-saas).

### Configure Allowed Host Domains

For production deployments, you need to configure allowed host domains to prevent host header attacks. Add the `ALLOWED_HOST_DOMAINS` environment variable to your `config/deploy.yml`:

```yaml
env:
  clear:
    ALLOWED_HOST_DOMAINS: your-domain.com,subdomain.your-domain.com
```

Or if you prefer to keep it as a secret, add it to `.kamal/secrets` and reference it in the `secret` section:

```yaml
env:
  secret:
    - ALLOWED_HOST_DOMAINS
```

The application will automatically allow access from the specified domains and their subdomains.

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

## REST API

Fizzy provides a REST API for programmatic access to boards, cards, and comments. See [API.md](API.md) for complete API documentation.

### Quick Start

1. Create an API token through the admin interface at `/admin/api_tokens`
2. Grant board access to the token (see [API.md](API.md) for details)
3. Use the token in API requests with the `Authorization: Bearer TOKEN` header

Example:
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://fizzy.localhost:3006/api/boards
```

## SaaS gem

37signals bundles Fizzy with [`fizzy-saas`](https://github.com/basecamp/fizzy-saas), a companion gem that links Fizzy with our billing system and contains our production setup.

This gem depends on some private git repositories and it is not meant to be used by third parties. But we hope it can serve as inspiration for anyone wanting to run fizzy on their own infrastructure.


## Contributing

We welcome contributions! Please read our [style guide](STYLE.md) before submitting code.

## License

Fizzy is released under the [O'Saasy License](LICENSE.md).

