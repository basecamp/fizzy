#!/usr/bin/env bash
# fizzy CLI installer
# Usage: curl -fsSL https://raw.githubusercontent.com/basecamp/fizzy/main/cli/install.sh | bash
#
# Environment variables:
#   FIZZY_INSTALL_DIR  - Installation directory (default: ~/.local/share/fizzy)
#   FIZZY_BIN_DIR      - Symlink directory (default: ~/.local/bin)
#   FIZZY_REPO         - GitHub repo (default: basecamp/fizzy)
#   FIZZY_REF          - Git ref to install (default: main)
#   FIZZY_COMMIT       - Skip API call, use this commit SHA for version tracking

set -euo pipefail

REPO="${FIZZY_REPO:-basecamp/fizzy}"
REF="${FIZZY_REF:-main}"
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

# Get commit SHA from GitHub API (best-effort, not critical)
get_commit_sha() {
  # Allow override via environment (useful for CI/offline installs)
  if [[ -n "${FIZZY_COMMIT:-}" ]]; then
    echo "$FIZZY_COMMIT"
    return 0
  fi

  # Try GitHub API (may fail due to rate limits)
  local sha
  sha=$(curl -fsSL --max-time 5 "https://api.github.com/repos/$REPO/commits/$REF" 2>/dev/null | \
    grep '"sha"' | head -1 | cut -d'"' -f4 | cut -c1-7) || true

  if [[ -n "$sha" ]]; then
    echo "$sha"
  fi
}

# Download and install
install_fizzy() {
  info "Installing fizzy to $INSTALL_DIR"

  # Create directories
  mkdir -p "$INSTALL_DIR" "$BIN_DIR"

  # Download from GitHub
  local tmp
  tmp=$(mktemp -d)
  trap "rm -rf $tmp" EXIT

  # Determine archive name (branch uses refs/heads/, tags use refs/tags/)
  local archive_url="https://github.com/$REPO/archive/refs/heads/$REF.tar.gz"
  local strip_prefix="fizzy-$REF"

  info "Downloading from GitHub ($REF)..."
  if ! curl -fsSL "$archive_url" | tar -xz -C "$tmp" --strip-components=2 "$strip_prefix/cli" 2>/dev/null; then
    # Try as tag instead
    archive_url="https://github.com/$REPO/archive/refs/tags/$REF.tar.gz"
    curl -fsSL "$archive_url" | tar -xz -C "$tmp" --strip-components=2 "$strip_prefix/cli" || \
      die "Failed to download from $REPO at ref $REF"
  fi

  # Copy files
  cp -r "$tmp"/* "$INSTALL_DIR/"

  # Write commit SHA for version tracking (best-effort)
  local commit_sha
  commit_sha=$(get_commit_sha)
  if [[ -n "$commit_sha" ]]; then
    echo "$commit_sha" > "$INSTALL_DIR/.commit"
    info "Installed fizzy $REF ($commit_sha)"
  else
    # No commit SHA available, just record the ref
    echo "$REF" > "$INSTALL_DIR/.commit"
    info "Installed fizzy $REF"
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
