#!/usr/bin/env bash
# fizzy CLI installer
# Usage: curl -fsSL https://raw.githubusercontent.com/basecamp/fizzy/main/cli/install.sh | bash

set -euo pipefail

REPO="basecamp/fizzy"
INSTALL_DIR="${FIZZY_INSTALL_DIR:-$HOME/.local/share/fizzy}"
BIN_DIR="${FIZZY_BIN_DIR:-$HOME/.local/bin}"

info() { echo "==> $*"; }
warn() { echo "Warning: $*" >&2; }
die() { echo "Error: $*" >&2; exit 1; }

# Check dependencies
check_deps() {
  local missing=()

  # Check bash version (need 4+)
  if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    missing+=("bash 4+ (found ${BASH_VERSION})")
  fi

  command -v curl &>/dev/null || missing+=("curl")
  command -v jq &>/dev/null || missing+=("jq")

  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing dependencies: ${missing[*]}"
  fi
}

# Get latest commit SHA from GitHub API
get_commit_sha() {
  curl -fsSL "https://api.github.com/repos/$REPO/commits/main" 2>/dev/null | \
    grep '"sha"' | head -1 | cut -d'"' -f4 | cut -c1-7
}

# Download and install
install_fizzy() {
  info "Installing fizzy to $INSTALL_DIR"

  # Create directories
  mkdir -p "$INSTALL_DIR" "$BIN_DIR"

  # Download latest from main branch
  local tmp
  tmp=$(mktemp -d)
  trap "rm -rf $tmp" EXIT

  info "Downloading from GitHub..."
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/main.tar.gz" | \
    tar -xz -C "$tmp" --strip-components=2 "fizzy-main/cli"

  # Copy files
  cp -r "$tmp"/* "$INSTALL_DIR/"

  # Write commit SHA for version tracking
  local commit_sha
  commit_sha=$(get_commit_sha)
  if [[ -n "$commit_sha" ]]; then
    echo "$commit_sha" > "$INSTALL_DIR/.commit"
    info "Installed fizzy main ($commit_sha)"
  else
    echo "unknown" > "$INSTALL_DIR/.commit"
    info "Installed fizzy main"
  fi

  # Make executable
  chmod +x "$INSTALL_DIR/bin/fizzy"

  # Create symlink in bin
  ln -sf "$INSTALL_DIR/bin/fizzy" "$BIN_DIR/fizzy"
}

# Setup completions hint
setup_hint() {
  echo
  info "Setup shell completions (optional):"
  echo
  echo "  # Bash (add to ~/.bashrc)"
  echo "  source $INSTALL_DIR/completions/fizzy.bash"
  echo
  echo "  # Zsh (add to ~/.zshrc)"
  echo "  fpath=($INSTALL_DIR/completions \$fpath)"
  echo "  autoload -Uz compinit && compinit"
  echo
}

# Check PATH
check_path() {
  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR is not in your PATH"
    echo "  Add to your shell profile:"
    echo "    export PATH=\"$BIN_DIR:\$PATH\""
  fi
}

main() {
  info "fizzy CLI installer"
  echo

  check_deps
  install_fizzy
  setup_hint
  check_path

  echo
  info "Done! Run 'fizzy auth login' to get started."
}

main "$@"
