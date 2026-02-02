## Deploying with Docker

We provide pre-built Docker images that can be used to run Fizzy on your own server.

If you don't need to change the source code, and just want the out-of-the-box Fizzy experience, this can be a great way to get started.

You'll find the latest version of Fizzy's Docker image at `ghcr.io/basecamp/fizzy:main`.
To run it you'll need three things: a machine that runs Docker; a mounted volume (so that your database is stored somewhere that is kept around between restarts); and some environment variables for configuration.

### Mounting a storage volume

The standard Fizzy setup keeps all of its storage inside the path `/rails/storage`.
By default Docker containers don't persist storage between runs, so you'll want to mount a persistent volume into that location.

The simplest way to do this is with the `--volume` flag with `docker run`. For example:

```sh
docker run --volume fizzy:/rails/storage ghcr.io/basecamp/fizzy:main
```

That will create a named volume (called `fizzy`) and mount it into the correct path.
Docker will manage where that volume is actually stored on your server.

You can also specify the data location yourself, mount a network drive, and more.
Check the Docker documentation to find out more about what's available.

### Configuring with environment variables

To configure your Fizzy installation, you can use environment variables.
Fizzy has several of them.
Many of these are optional, but at a minimum you'll want to configure your secret key, your SSL domain, and your SMTP email settings.

#### Secret Key Base

Various features inside Fizzy rely on cryptography to work (such as secure links).
To set this up, you need to provide a secret value that will be used as the basis of those secrets.
This value can be anything, but it should be unguessable, and specific to your instance.

You can use any long random string for this, or you can have the Fizzy codebase generate one for you by running:

```sh
bin/rails secret
```

Once you have one, set it in the `SECRET_KEY_BASE` environment variable:

```sh
docker run --env SECRET_KEY_BASE=abcdefabcdef ...
```

#### SSL

If you want the Fizzy container to handle its own SSL automatically, you just need to specify the domain name that you're running it on.
You can do that with the `TLS_DOMAIN` environment variable.
Note that if you're using SSL, you'll want to allow traffic on ports 80 and 443.
So if you were running on `fizzy.example.com` you could enable SSL like this:

```sh
docker run --publish 80:80 --publish 443:443 --env TLS_DOMAIN=fizzy.example.com ...
```

If you are terminating SSL in some other proxy in front of Fizzy, then you don't need to set `TLS_DOMAIN`, and can just publish port 80:
```sh
docker run --publish 80:80 ...
```

If you aren't using SSL at all (for example, if you want to run it locally on your laptop) then you should specify `DISABLE_SSL=true` instead:

```sh
docker run --publish 80:80 --env DISABLE_SSL=true ...
```

#### SMTP Email

Fizzy needs to be able to send email for its sign up/sign in flow, and for its regular summary emails.
The easiest way to set this up is to use a 3rd-party email provider (such as Postmark, Sendgrid, and so on).
You can then plug all your SMTP settings from that provider into Fizzy via the following environment variables:

- `MAILER_FROM_ADDRESS` - the "from" address that Fizzy should use to send email
- `SMTP_ADDRESS` - the address of the SMTP server you'll send through
- `SMTP_PORT` - the port number (defaults to 465 when `SMTP_TLS` is set, 587 otherwise)
- `SMTP_USERNAME`/`SMTP_PASSWORD` - the credentials for logging in to the SMTP server

Less commonly, you might also need to set some of the following:

- `SMTP_TLS` - set to `true` only for servers requiring implicit TLS (SMTPS on port 465); STARTTLS is used automatically by default so most servers don't need this
- `SMTP_DOMAIN` - the domain name advertised to the server when connecting
- `SMTP_AUTHENTICATION` - if you need an authentication method other than the default `plain`
- `SMTP_SSL_VERIFY_MODE` - set to `none` to skip certificate verification (for self-signed certs)

You can find out more about all these settings in the [Rails Action Mailer documentation](https://guides.rubyonrails.org/action_mailer_basics.html#action-mailer-configuration).

#### Base URL

Fizzy needs to know the public URL of your instance so it can generate correct links in certain situations (like when sending emails).
Set `BASE_URL` to the full URL where your Fizzy instance is accessible:

```sh
docker run --env BASE_URL=https://fizzy.example.com ...
```

#### VAPID keys

Fizzy can also send Web Push notifications.
To do this it needs a VAPID key pair.

You can create your own keys by starting a development console with:

```sh
bin/rails c
```

And then run the following to create the keypair:

```ruby
vapid_key = WebPush.generate_key

puts "VAPID_PRIVATE_KEY=#{vapid_key.private_key}"
puts "VAPID_PUBLIC_KEY=#{vapid_key.public_key}"
```

Set those in the `VAPID_PRIVATE_KEY` and `VAPID_PUBLIC_KEY` environment variables.

#### S3 storage (optional)

If you'd prefer that uploaded files were stored in an S3 bucket rather than in your mounted volume, you can set that up.

First set `ACTIVE_STORAGE_SERVICE` to `s3`.
Then set the following as appropriate for your S3 bucket:

- `S3_BUCKET`
- `S3_REGION`
- `S3_ACCESS_KEY_ID`
- `S3_SECRET_ACCESS_KEY`

If you're using a provider other than AWS, you will also need some of the following:

- `S3_ENDPOINT`
- `S3_FORCE_PATH_STYLE`
- `S3_REQUEST_CHECKSUM_CALCULATION`
- `S3_RESPONSE_CHECKSUM_VALIDATION`

#### Multi-tenant mode

By default, when you run the Fizzy Docker image you'll be limited to creating a single account (although that account can have as many users as you like).
This is for convenience: typically when you self-host you'll be running a single account, so in this mode new account signups are automatically disabled as soon as you've created your first account.

If you do want to allow multiple accounts to be created in your instance, set `MULTI_TENANT=true`

## Example

Here's an example of a `docker-compose.yml` that you could use to run Fizzy via `docker compose up`

```yaml
services:
  web:
    image: ghcr.io/basecamp/fizzy:main
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    environment:
      - SECRET_KEY_BASE=abcdefabcdef
      - TLS_DOMAIN=fizzy.example.com
      - BASE_URL=https://fizzy.example.com
      - MAILER_FROM_ADDRESS=fizzy@example.com
      - SMTP_ADDRESS=mail.example.com
      - SMTP_USERNAME=user
      - SMTP_PASSWORD=pass
      - VAPID_PRIVATE_KEY=myvapidprivatekey
      - VAPID_PUBLIC_KEY=myvapidpublickey
    volumes:
      - fizzy:/rails/storage

volumes:
  fizzy:
```
