## Deploying Fizzy with Kamal

If you'd like to run Fizzy on your own server while having the freedom to easily make changes to its code, we recommend deploying it with [Kamal](https://kamal-deploy.org/).
Kamal makes it easy to set up a bare server, copy the application to it, and manage the configuration settings that it uses.

(Kamal is also what we use to deploy Fizzy at 37signals. If you're curious about what our deployment configuration looks like, you can find it inside [`fizzy-saas`](https://github.com/basecamp/fizzy-saas).)

This repo contains a starter deployment file that you can modify for your own specific use. That file lives at [config/deploy.yml](config/deploy.yml), which is the default place where Kamal will look for it.

The steps to configure your very own Fizzy are:

1. Fork the repo
2. Initialize Kamal by running `kamal init`. This command generates the `.kamal` directory along with the required configuration files, including `.kamal/secrets`.
3. Edit few things in config/deploy.yml and .kamal/secrets
4. Run `kamal setup` to do your first deploy.

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
- `env/clear/BASE_URL`: The public URL of your Fizzy instance (e.g., `https://fizzy.example.com`). Used when generating links.
- `env/clear/MAILER_FROM_ADDRESS`: This is the email address that Fizzy will send emails from. It should usually be an address from the same domain where you're running Fizzy.
- `env/clear/SMTP_ADDRESS`: The address of an SMTP server that you can send email through. You can use a 3rd-party service for this, like Sendgrid or Postmark, in which case their documentation will tell you what to use for this.
- `env/clear/MULTI_TENANT`: Set to `true` if you want to allow multiple accounts to sign up on your server (by default, Fizzy will allow you to create a single account).

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
- `SMTP_USERNAME` & `SMTP_PASSWORD` should be valid credentials for your SMTP server. If you're using a 3rd-party service here, consult their documentation for what to use.
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

### Configuring file storage (Active Storage)

Production uses the local disk service by default. To use any other service defined in `config/storage.yml`, set `ACTIVE_STORAGE_SERVICE`.

To use the included `s3` service, set:

- `ACTIVE_STORAGE_SERVICE=s3`
- `S3_ACCESS_KEY_ID`
- `S3_BUCKET` (defaults to `fizzy-#{Rails.env}-activestorage`)
- `S3_REGION` (defaults to `us-east-1`)
- `S3_SECRET_ACCESS_KEY`

Optional for S3-compatible endpoints:

- `S3_ENDPOINT`
- `S3_FORCE_PATH_STYLE=true`
- `S3_REQUEST_CHECKSUM_CALCULATION` (defaults to `when_supported`)
- `S3_RESPONSE_CHECKSUM_VALIDATION` (defaults to `when_supported`)

