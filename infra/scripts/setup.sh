#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REQUIRED_NODE_VERSION="24.5.0"

cd "$PROJECT_DIR"

echo "Setting up Fizzy infrastructure environment..."
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "Node.js is not installed"
    echo ""
    echo "Install Node.js $REQUIRED_NODE_VERSION using your preferred method:"
    echo "  nvm:  nvm install $REQUIRED_NODE_VERSION"
    echo "  fnm:  fnm install $REQUIRED_NODE_VERSION"
    echo "  asdf: asdf install nodejs $REQUIRED_NODE_VERSION"
    exit 1
fi

CURRENT_VERSION=$(node -v | sed 's/v//')
CURRENT_MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
REQUIRED_MAJOR=$(echo "$REQUIRED_NODE_VERSION" | cut -d. -f1)

if [ "$CURRENT_MAJOR" != "$REQUIRED_MAJOR" ]; then
    echo "Node.js version mismatch"
    echo "  Current:  v$CURRENT_VERSION"
    echo "  Required: v$REQUIRED_NODE_VERSION"
    echo ""
    echo "Switch to the correct version:"
    echo "  nvm: nvm use (reads .nvmrc)"
    echo "  fnm: fnm use"
    exit 1
fi
echo "Node.js v$CURRENT_VERSION"

# Check Yarn
if ! command -v yarn &> /dev/null; then
    echo "Yarn is not installed. Install with: npm install -g yarn"
    exit 1
fi
echo "Yarn $(yarn -v)"

# Check GitHub token
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo ""
    echo "GITHUB_TOKEN not set (required for @zarpay/zar-cdk-lib)"
    echo ""
    echo "Set it with: export GITHUB_TOKEN=<your-pat>"
    echo "Generate at: https://github.com/settings/tokens (scope: read:packages)"
    exit 1
fi
echo "GITHUB_TOKEN set"

echo ""
echo "Installing dependencies..."
yarn install

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Configure AWS credentials (DevOpsPlayGround profile)"
echo "  2. Test synth: just infra-synth --environment=development --profile=DevOpsPlayGround"