#!/usr/bin/env bash
# self_update.sh - Self-update and uninstall commands for fizzy CLI

# Self-update constants
FIZZY_REPO="${FIZZY_REPO:-basecamp/fizzy}"
FIZZY_BRANCH="${FIZZY_BRANCH:-main}"
FIZZY_RAW_URL="https://raw.githubusercontent.com/$FIZZY_REPO/$FIZZY_BRANCH"
FIZZY_API_URL="https://api.github.com/repos/$FIZZY_REPO"

# cmd_self_update - Update fizzy CLI to latest version
cmd_self_update() {
  local force=false
  local check_only=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force|-f)
        force=true
        shift
        ;;
      --check)
        check_only=true
        shift
        ;;
      --help|-h)
        _self_update_help
        return 0
        ;;
      *)
        die "Unknown option: $1" $EXIT_USAGE
        ;;
    esac
  done

  # Check if this is a git checkout
  if [[ -d "$FIZZY_ROOT/.git" ]]; then
    json_error "Cannot self-update a git checkout" "usage" \
      "Use 'git pull' to update instead"
    return $EXIT_USAGE
  fi

  # Check if FIZZY_ROOT is writable
  if [[ ! -w "$FIZZY_ROOT" ]]; then
    local hint="Check permissions or reinstall with: curl -fsSL $FIZZY_RAW_URL/cli/install.sh | bash"
    # Detect Homebrew install
    if [[ "$FIZZY_ROOT" == */Cellar/* ]] || [[ "$FIZZY_ROOT" == */homebrew/* ]]; then
      hint="Use 'brew upgrade fizzy-cli' to update"
    fi
    json_error "Cannot update: $FIZZY_ROOT is not writable" "forbidden" "$hint"
    return $EXIT_FORBIDDEN
  fi

  # Get current commit (short SHA)
  local current_commit="$FIZZY_COMMIT"

  # Fetch remote commit
  local remote_commit
  remote_commit=$(_fetch_remote_commit) || {
    json_error "Failed to check for updates" "network" \
      "Check your internet connection and try again"
    return $EXIT_NETWORK
  }

  # Compare commits
  if [[ "$current_commit" == "$remote_commit" ]] && [[ "$force" != "true" ]]; then
    if [[ "$(get_format)" == "json" ]]; then
      json_output "true" '{
        "current_commit": "'"$current_commit"'",
        "remote_commit": "'"$remote_commit"'",
        "up_to_date": true,
        "updated": false
      }' "fizzy is up to date (main $current_commit)"
    else
      echo "fizzy is up to date (main $current_commit)"
    fi
    return 0
  fi

  # Check only mode
  if [[ "$check_only" == "true" ]]; then
    if [[ "$(get_format)" == "json" ]]; then
      json_output "true" '{
        "current_commit": "'"$current_commit"'",
        "remote_commit": "'"$remote_commit"'",
        "up_to_date": false,
        "updated": false
      }' "Update available: $current_commit → $remote_commit"
    else
      echo "Update available: $current_commit → $remote_commit"
      echo "Run 'fizzy self-update' to update"
    fi
    return 0
  fi

  # Perform update
  if [[ "$(get_format)" == "json" ]]; then
    echo "Updating fizzy $current_commit → $remote_commit..." >&2
  else
    echo "Updating fizzy $current_commit → $remote_commit..."
  fi

  if _perform_update "$remote_commit"; then
    if [[ "$(get_format)" == "json" ]]; then
      json_output "true" '{
        "current_commit": "'"$current_commit"'",
        "remote_commit": "'"$remote_commit"'",
        "new_commit": "'"$remote_commit"'",
        "up_to_date": true,
        "updated": true
      }' "Updated fizzy to main ($remote_commit)"
    else
      echo "Updated fizzy to main ($remote_commit)"
    fi
    return 0
  else
    json_error "Update failed" "api_error" \
      "Try running the installer manually: curl -fsSL $FIZZY_RAW_URL/cli/install.sh | bash"
    return $EXIT_API
  fi
}

# Fetch latest commit SHA from GitHub API (short form)
_fetch_remote_commit() {
  curl -fsSL --max-time 10 "$FIZZY_API_URL/commits/$FIZZY_BRANCH" 2>/dev/null | \
    grep '"sha"' | head -1 | cut -d'"' -f4 | cut -c1-7
}

# Perform the actual update
_perform_update() {
  local new_commit="${1:-}"
  local tmp
  tmp=$(mktemp -d)
  trap "rm -rf '$tmp'" RETURN

  # Download latest CLI
  if ! curl -fsSL --max-time 60 "https://github.com/$FIZZY_REPO/archive/refs/heads/$FIZZY_BRANCH.tar.gz" | \
       tar -xz -C "$tmp" --strip-components=2 "fizzy-$FIZZY_BRANCH/cli" 2>/dev/null; then
    return 1
  fi

  # Copy new files over existing installation
  cp -r "$tmp"/* "$FIZZY_ROOT/" || return 1

  # Write commit SHA for version tracking
  if [[ -n "$new_commit" ]]; then
    echo "$new_commit" > "$FIZZY_ROOT/.commit"
  fi

  # Ensure executable
  chmod +x "$FIZZY_ROOT/bin/fizzy" || return 1

  return 0
}

# cmd_uninstall - Remove fizzy CLI installation
cmd_uninstall() {
  local force=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force|-f)
        force=true
        shift
        ;;
      --help|-h)
        _uninstall_help
        return 0
        ;;
      *)
        die "Unknown option: $1" $EXIT_USAGE
        ;;
    esac
  done

  # Check if this is a git checkout
  if [[ -d "$FIZZY_ROOT/.git" ]]; then
    json_error "Cannot uninstall a git checkout" "usage" \
      "Just delete the directory manually if needed"
    return $EXIT_USAGE
  fi

  # Detect Homebrew install
  if [[ "$FIZZY_ROOT" == */Cellar/* ]] || [[ "$FIZZY_ROOT" == */homebrew/* ]]; then
    json_error "Cannot uninstall Homebrew installation" "usage" \
      "Use 'brew uninstall fizzy-cli' instead"
    return $EXIT_USAGE
  fi

  # Check if FIZZY_ROOT is writable
  if [[ ! -w "$FIZZY_ROOT" ]] || [[ ! -w "$(dirname "$FIZZY_ROOT")" ]]; then
    json_error "Cannot uninstall: insufficient permissions" "forbidden" \
      "Check permissions on $FIZZY_ROOT"
    return $EXIT_FORBIDDEN
  fi

  # Confirm uninstall unless --force
  if [[ "$force" != "true" ]]; then
    echo "This will remove fizzy from: $FIZZY_ROOT"
    echo "Run with --force to confirm, or press Ctrl+C to cancel"
    return 0
  fi

  # Find and remove symlink in common bin directories
  local bin_link
  for bin_dir in "$HOME/.local/bin" "$HOME/bin" "/usr/local/bin"; do
    bin_link="$bin_dir/fizzy"
    if [[ -L "$bin_link" ]] && [[ "$(readlink "$bin_link")" == "$FIZZY_ROOT/bin/fizzy" ]]; then
      rm -f "$bin_link" 2>/dev/null || true
    fi
  done

  # Remove installation directory
  if rm -rf "$FIZZY_ROOT"; then
    if [[ "$(get_format)" == "json" ]]; then
      json_output "true" '{
        "uninstalled": true,
        "path": "'"$FIZZY_ROOT"'"
      }' "fizzy has been uninstalled"
    else
      echo "fizzy has been uninstalled from $FIZZY_ROOT"
    fi
    return 0
  else
    json_error "Failed to remove $FIZZY_ROOT" "api_error" \
      "Try removing manually: rm -rf $FIZZY_ROOT"
    return $EXIT_API
  fi
}

# Help for self-update command
_self_update_help() {
  if [[ "$(get_format)" == "json" ]]; then
    cat <<'EOF'
{
  "command": "fizzy self-update",
  "description": "Update fizzy CLI to the latest version",
  "options": [
    {"flag": "--check", "description": "Check for updates without installing"},
    {"flag": "--force, -f", "description": "Force update even if already up to date"}
  ],
  "examples": [
    {"cmd": "fizzy self-update", "desc": "Update to latest version"},
    {"cmd": "fizzy self-update --check", "desc": "Check if update is available"},
    {"cmd": "fizzy self-update --force", "desc": "Force reinstall current version"}
  ]
}
EOF
  else
    cat <<'EOF'
fizzy self-update - Update fizzy CLI to the latest version

USAGE
  fizzy self-update [options]

OPTIONS
  --check       Check for updates without installing
  --force, -f   Force update even if already up to date

EXAMPLES
  fizzy self-update           Update to latest version
  fizzy self-update --check   Check if update is available
  fizzy self-update --force   Force reinstall current version
EOF
  fi
}

# Help for uninstall command
_uninstall_help() {
  if [[ "$(get_format)" == "json" ]]; then
    cat <<'EOF'
{
  "command": "fizzy uninstall",
  "description": "Remove fizzy CLI from your system",
  "options": [
    {"flag": "--force, -f", "description": "Skip confirmation and remove immediately"}
  ],
  "examples": [
    {"cmd": "fizzy uninstall", "desc": "Show what will be removed"},
    {"cmd": "fizzy uninstall --force", "desc": "Remove fizzy immediately"}
  ]
}
EOF
  else
    cat <<'EOF'
fizzy uninstall - Remove fizzy CLI from your system

USAGE
  fizzy uninstall [options]

OPTIONS
  --force, -f   Skip confirmation and remove immediately

EXAMPLES
  fizzy uninstall           Show what will be removed
  fizzy uninstall --force   Remove fizzy immediately
EOF
  fi
}
