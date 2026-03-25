# GitHub Actions on `pi5-01`

This branch deploys Fizzy from a self-hosted GitHub Actions runner on `pi5-01`.

The runner host only needs:

- Docker
- SSH access to `homelab-rcc`
- the GitHub Actions runner service

Kamal itself runs inside the official `ghcr.io/basecamp/kamal:v2.10.1` container during the workflow.

## Branch model

- Keep self-hosted deployment work on the `self-hosted` branch.
- Set the fork default branch to `self-hosted` once the repo-side workflow is in place.
- The deploy-related workflows are `workflow_dispatch` only. Nothing auto-builds or auto-deploys on push.

## Repo secrets

Sync app secrets from `.env.kamal.local` into the fork with:

```bash
script/sync-github-secrets-from-kamal-env.sh joshyorko/fizzy
```

This pushes:

- `SECRET_KEY_BASE`
- `VAPID_PUBLIC_KEY`
- `VAPID_PRIVATE_KEY`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `S3_ACCESS_KEY_ID`
- `S3_SECRET_ACCESS_KEY`
- `CLOUDFLARED_TOKEN`
- `KAMAL_REGISTRY_PASSWORD` from `KAMAL_REGISTRY_PASSWORD` or `gh auth token`

If `config/master.key` exists locally, the script also syncs `RAILS_MASTER_KEY`.

## Runner install

Install and register the runner on `pi5-01` as a system service with:

```bash
script/install-self-hosted-runner-on-pi5-01.sh joshyorko/fizzy
```

What it does:

- creates a dedicated SSH key on `pi5-01` for `homelab-rcc`
- adds that public key to `kdlocpanda@homelab-rcc`
- adds a `homelab-rcc` host entry on `pi5-01`
- downloads the GitHub Actions runner for Linux ARM64
- registers it to the repo with labels `pi5-01`, `kamal`, `fizzy`
- installs and starts it as a system service

The workflow expects `pi5-01` to be able to SSH to `homelab-rcc` without prompting.

## Deploy workflow

`.github/workflows/deploy-self-hosted.yml` runs only by manual dispatch.

## Diagnostics workflow

`.github/workflows/diagnostics-self-hosted.yml` runs only by manual dispatch and does not deploy anything.

Recommended first run:

1. Run `diagnostics-self-hosted.yml` with `command=summary`.
2. Run `diagnostics-self-hosted.yml` with `command=app_logs` if you want to prove Kamal can reach the current Fizzy app and stream logs.

Recommended order:

1. Run `diagnostics-self-hosted.yml` with `command=summary`.
2. Run `publish-image.yml`.
3. After the image exists in GHCR, run `deploy-self-hosted.yml`.

Diagnostics dispatch supports:

- `summary`: `kamal version`, `kamal details`, `kamal app version`, `kamal app containers`, and `kamal proxy details`
- `app_logs`: `kamal app logs --primary --lines N`
- `proxy_logs`: `kamal proxy logs --primary --lines N`
- `app_details`: `kamal app details`
- `proxy_details`: `kamal proxy details`
- `audit`: `kamal audit`

The diagnostics workflow:

- writes `.env.kamal.local` and `config/master.key` from GitHub secrets
- verifies `pi5-01` can SSH to `homelab-rcc`
- pulls `ghcr.io/basecamp/kamal:v2.10.1`
- runs the selected Kamal read-only diagnostic command set inside that official container
- fails the workflow if any selected Kamal check fails

Manual deploy dispatch supports:

- `deploy`: normal `kamal deploy`
- `setup`: first-time `kamal setup`

The workflow:

- writes `.env.kamal.local` and `config/master.key` from GitHub secrets
- waits for `ghcr.io/joshyorko/fizzy:sha-<short_sha>` to exist
- pulls `ghcr.io/basecamp/kamal:v2.10.1`
- runs Kamal inside that official container with the repo, SSH config, Docker config, and Docker socket mounted in
- runs `kamal setup --skip-push --version …` or `kamal deploy --skip-push --version …`

This matches the current Kamal docs:

- `registry/server` selects a non-local registry
- Kamal supports running the CLI from Docker when the runner does not have a local Ruby toolchain
- `kamal deploy --skip-push --version VERSION` deploys an already-published image
