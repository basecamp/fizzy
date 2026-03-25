#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-$(git remote get-url origin | sed -E 's#.*github.com[:/]([^/]+/[^/.]+)(\\.git)?#\1#')}"
PI_HOST="${PI_HOST:-pi5-01}"
APP_HOST="${APP_HOST:-homelab-rcc}"
RUNNER_VERSION="${RUNNER_VERSION:-2.328.0}"
RUNNER_NAME="${RUNNER_NAME:-pi5-01-fizzy}"
RUNNER_LABELS="${RUNNER_LABELS:-pi5-01,kamal,fizzy}"
RUNNER_DIR="${RUNNER_DIR:-actions-runner-fizzy}"
PI_USER="${PI_USER:-kdlocpanda}"
APP_USER="${APP_USER:-kdlocpanda}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

registration_token="$(
  gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    "/repos/${REPO}/actions/runners/registration-token" \
    --jq '.token'
)"

ssh "$PI_HOST" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && test -f ~/.ssh/id_ed25519_homelab_rcc || ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519_homelab_rcc"
pubkey="$(ssh "$PI_HOST" "cat ~/.ssh/id_ed25519_homelab_rcc.pub")"

ssh "$APP_HOST" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && grep -qxF '$pubkey' ~/.ssh/authorized_keys || printf '%s\n' '$pubkey' >> ~/.ssh/authorized_keys"

ssh "$PI_HOST" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/config ~/.ssh/known_hosts && chmod 600 ~/.ssh/config ~/.ssh/known_hosts"

ssh "$PI_HOST" "grep -q '^Host ${APP_HOST}\$' ~/.ssh/config || cat >> ~/.ssh/config <<'EOF'
Host ${APP_HOST}
  HostName 10.10.10.106
  User ${APP_USER}
  IdentityFile ~/.ssh/id_ed25519_homelab_rcc
  IdentitiesOnly yes
EOF"

app_host_key="$(ssh-keyscan -H 10.10.10.106 2>/dev/null)"
ssh "$PI_HOST" "grep -qxF '$app_host_key' ~/.ssh/known_hosts || printf '%s\n' '$app_host_key' >> ~/.ssh/known_hosts"

ssh "$PI_HOST" "set -euo pipefail
  mkdir -p ~/${RUNNER_DIR}
  cd ~/${RUNNER_DIR}
  if [ ! -f .runner-version ] || [ \"\$(cat .runner-version)\" != '${RUNNER_VERSION}' ]; then
    rm -rf ./*
    curl -fsSL https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz -o actions-runner.tar.gz
    tar xzf actions-runner.tar.gz
    rm -f actions-runner.tar.gz
    echo '${RUNNER_VERSION}' > .runner-version
  fi

  if [ -x ./svc.sh ]; then
    sudo ./svc.sh stop || true
    sudo ./svc.sh uninstall || true
  fi

  ./config.sh --unattended --replace --url https://github.com/${REPO} --token '${registration_token}' --name '${RUNNER_NAME}' --labels '${RUNNER_LABELS}' --work _work
  sudo ./svc.sh install ${PI_USER}
  sudo ./svc.sh start
"

ssh "$PI_HOST" "ssh -o BatchMode=yes ${APP_HOST} 'echo runner-to-app-ssh-ok >/dev/null'"

echo "Runner ${RUNNER_NAME} installed on ${PI_HOST} for ${REPO}"
