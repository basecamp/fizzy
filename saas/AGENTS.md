# Fizzy SaaS

37signals' hosted Fizzy: billing, our production setup, our deploy destinations. Apply this only when SaaS mode is enabled — the root `AGENTS.md` has the check.

`bin/rails saas:enable` creates `tmp/saas.txt`; `saas:disable` removes it. `Fizzy.saas?` also reads `SAAS` from the environment, where anything but `false` enables and `SAAS=false` forces off even with the file present (`lib/fizzy.rb`) — that path is for the production image and `bin/ci`, not for switching a checkout. Enabling swaps the bundle to `Gemfile.saas` and the default database adapter to MySQL, so it changes what every `bin/rails` and `bin/kamal` command does.

`README.md` covers the environments, Stripe, push credentials, and maintenance mode. What it doesn't say:

`saas:enable` is a prerequisite for deploying, not just for local development. Only under that flag does `bin/kamal` pass `-c` pointing at this gem's `config/deploy.yml`. Skip it and Kamal reads the root `config/deploy.yml` instead — the self-hosting example, which knows nothing about our destinations.

Destinations are production, staging, beta, and beta1, one `config/deploy.<destination>.yml` each. `beta` is a template requiring the `BETA_NUMBER` env var; `beta1` is the only numbered target that exists. The `.kamal/secrets.beta2` through `secrets.beta4` symlinks are leftovers and don't make those destinations real.
