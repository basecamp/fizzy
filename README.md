# Dayzy

This is the source code of [Dayzy](https://fizzy.do/), the Kanban tracking tool for issues and ideas by [37signals](https://37signals.com).


## Running your own Dayzy instance

If you want to run your own Dayzy instance, but don't need to change its code, you can use our pre-built Docker image.
You'll need access to a server on which you can run Docker, and you'll need to configure some options to customize your installation.

You can find the details of how to do a Docker-based deployment in our [Docker deployment guide](docs/docker-deployment.md).

If you want more flexibility to customize your Dayzy installation by changing its code, and deploy those changes to your server, then we recommend you deploy Dayzy with Kamal. You can find a complete walkthrough of doing that in our [Kamal deployment guide](docs/kamal-deployment.md).


## Development

You are welcome -- and encouraged -- to modify Dayzy to your liking.
Please see our [Development guide](docs/development.md) for the full setup guide.

### Quick start

```sh
bin/setup       # Install gems, create and seed the database
bin/dev         # Start the development server on port 3006
```

Open **http://app.fizzy.localhost:3006** in your browser.

To log in, enter `david@example.com` and grab the magic-link verification code from the browser console.

### Running tests

```sh
bin/rails test   # Unit tests (fast)
bin/ci           # Full CI suite (style, security, unit, system tests)
```


## Contributing

We welcome contributions! Please read our [style guide](STYLE.md) before submitting code.


## License

Dayzy is released under the [O'Saasy License](LICENSE.md).
