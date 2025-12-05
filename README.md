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
# If you need to access private GitHub gems, create a token file:
echo "your_github_token" > .github_token

# Build and start the container
docker-compose up

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

2. **Access MailHog**: The MailHog web UI is available at `http://your-server-hostname:8025` to view all captured emails.

3. **Port forwarding (optional)**: If you prefer to access via localhost, you can use SSH port forwarding:
   ```sh
   # Forward app port
   ssh -L 3006:localhost:3006 user@your-server
   
   # Forward MailHog port
   ssh -L 8025:localhost:8025 user@your-server
   ```
   Then access at http://localhost:3006 and http://localhost:8025.

#### Email Development with MailHog

MailHog is included as an SMTP proxy for development. It captures all emails sent by the application and provides a web interface to view them.

**Viewing Emails**:
- Open http://localhost:8025 (or your server hostname:8025) in your browser
- All emails sent by the app will appear in the MailHog interface
- Click on any email to view its full content, including HTML and text versions

**How it works**:
- When you register or request a magic link, the email is sent to MailHog instead of a real SMTP server
- The magic link code is included in the email body
- You can copy the code from MailHog and use it to sign in

**Disabling MailHog**: If you want to use letter_opener or console output instead, remove the `SMTP_HOST` environment variable from `docker-compose.yml` and restart:
```sh
docker-compose down
# Edit docker-compose.yml to remove SMTP_HOST and SMTP_PORT
docker-compose up -d
```

**Note**: If your Gemfile includes private GitHub gems, create a `.github_token` file with your GitHub personal access token. If you don't need private gems, create an empty file: `touch .github_token`. The `.github_token` file is git-ignored for security.

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

## SaaS gem

37signals bundles Fizzy with [`fizzy-saas`](https://github.com/basecamp/fizzy-saas), a companion gem that links Fizzy with our billing system and contains our production setup.

This gem depends on some private git repositories and it is not meant to be used by third parties. But we hope it can serve as inspiration for anyone wanting to run fizzy on their own infrastructure.


## Contributing

We welcome contributions! Please read our [style guide](STYLE.md) before submitting code.

## License

Fizzy is released under the [O'Saasy License](LICENSE.md).

