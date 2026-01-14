#!/usr/bin/env bash
# self_update.sh - Self-update command for fizzy CLI

# Self-update constants
FIZZY_REPO="${FIZZY_REPO:-basecamp/fizzy}"
FIZZY_BRANCH="${FIZZY_BRANCH:-main}"
FIZZY_RAW_URL="https://raw.githubusercontent.com/$FIZZY_REPO/$FIZZY_BRANCH"

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

  # Get current version
  local current_version="$FIZZY_VERSION"

  # Fetch remote version
  local remote_version
  remote_version=$(_fetch_remote_version) || {
    json_error "Failed to check for updates" "network" \
      "Check your internet connection and try again"
    return $EXIT_NETWORK
  }

  # Compare versions
  if [[ "$current_version" == "$remote_version" ]] && [[ "$force" != "true" ]]; then
    if [[ "$(get_format)" == "json" ]]; then
      json_output "true" '{
        "current_version": "'"$current_version"'",
        "remote_version": "'"$remote_version"'",
        "up_to_date": true,
        "updated": false
      }' "fizzy is up to date ($current_version)"
    else
      echo "fizzy is up to date ($current_version)"
    fi
    return 0
  fi

  # Check only mode
  if [[ "$check_only" == "true" ]]; then
    if [[ "$(get_format)" == "json" ]]; then
      json_output "true" '{
        "current_version": "'"$current_version"'",
        "remote_version": "'"$remote_version"'",
        "up_to_date": false,
        "updated": false
      }' "Update available: $current_version → $remote_version"
    else
      echo "Update available: $current_version → $remote_version"
      echo "Run 'fizzy self-update' to update"
    fi
    return 0
  fi

  # Perform update
  if [[ "$(get_format)" == "json" ]]; then
    echo "Updating fizzy $current_version → $remote_version..." >&2
  else
    echo "Updating fizzy $current_version → $remote_version..."
  fi

  if _perform_update; then
    # Re-read version after update
    local new_version
    new_version="$(cat "$FIZZY_ROOT/VERSION" 2>/dev/null || echo "unknown")"

    if [[ "$(get_format)" == "json" ]]; then
      json_output "true" '{
        "current_version": "'"$current_version"'",
        "remote_version": "'"$remote_version"'",
        "new_version": "'"$new_version"'",
        "up_to_date": true,
        "updated": true
      }' "Updated fizzy to $new_version"
    else
      echo "Updated fizzy to $new_version"
    fi
    return 0
  else
    json_error "Update failed" "api_error" \
      "Try running the installer manually: curl -fsSL $FIZZY_RAW_URL/cli/install.sh | bash"
    return $EXIT_API
  fi
}

# Fetch remote VERSION file
_fetch_remote_version() {
  curl -fsSL --max-time 10 "$FIZZY_RAW_URL/cli/VERSION" 2>/dev/null | tr -d '[:space:]'
}

# Perform the actual update
_perform_update() {
  local tmp
  tmp=$(mktemp -d)
  trap "rm -rf '$tmp'" RETURN

  # Download latest CLI
  if ! curl -fsSL --max-time 60 "https://github.com/$FIZZY_REPO/archive/refs/heads/$FIZZY_BRANCH.tar.gz" | \
       tar -xz -C "$tmp" --strip-components=2 "fizzy-$FIZZY_BRANCH/cli" 2>/dev/null; then
    return 1
  fi

  # Backup current installation (optional, for rollback)
  # cp -r "$FIZZY_ROOT" "$FIZZY_ROOT.bak" 2>/dev/null || true

  # Copy new files over existing installation
  cp -r "$tmp"/* "$FIZZY_ROOT/" || return 1

  # Ensure executable
  chmod +x "$FIZZY_ROOT/bin/fizzy" || return 1

  return 0
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
