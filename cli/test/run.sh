#!/usr/bin/env bash
# Test runner for fizzy
# Runs the bats test suite

set -euo pipefail
cd "$(dirname "$0")"

if ! command -v bats &>/dev/null; then
  echo "Error: bats not found. Install with: brew install bats-core" >&2
  exit 1
fi

exec bats "$@" *.bats
