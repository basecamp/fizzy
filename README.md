# Fizzy

This is the source code of [Fizzy](https://fizzy.do/), the Kanban tracking tool for issues and ideas by [37signals](https://37signals.com).


## Running your own Fizzy instance

The easiest way to self-host Fizzy is with [ONCE](https://github.com/basecamp/once).
It will guide you through the initial setup, and keep your instance up to date automatically. It has everything you need for a fully-functional, single-machine deployment.

To get started, run this on the machine where you want to install Fizzy:

```sh
curl https://get.once.com/fizzy | sh
```

### Deploying with Docker

If you'd rather run our pre-built Docker image yourself, you can find the details in our [Docker deployment guide](docs/docker-deployment.md).

### Deploying with Kamal

If you want more flexibility to customize your Fizzy installation by changing its code, and deploy those changes to your server, then we recommend you deploy Fizzy with Kamal. You can find a complete walkthrough of doing that in our [Kamal deployment guide](docs/kamal-deployment.md).


## Development

You are welcome -- and encouraged -- to modify Fizzy to your liking.
Please see our [Development guide](docs/development.md) for how to get Fizzy set up for local development.


## Contributing

We welcome contributions! Please read our [style guide](STYLE.md) before submitting code.


## License

Fizzy is released under the [O'Saasy License](LICENSE.md).
