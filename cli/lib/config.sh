#!/usr/bin/env bash
# config.sh - Layered configuration system for fizzy
#
# Config hierarchy (later overrides earlier):
#   1. /etc/fizzy/config.json (system-wide)
#   2. ~/.config/fizzy/config.json (user/global)
#   3. <git-root>/.fizzy/config.json (repo)
#   4. <cwd>/.fizzy/config.json (local, walks up tree)
#   5. Environment variables
#   6. Command-line flags


# Paths

FIZZY_SYSTEM_CONFIG_DIR="${FIZZY_SYSTEM_CONFIG_DIR:-/etc/fizzy}"
FIZZY_GLOBAL_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fizzy"
FIZZY_LOCAL_CONFIG_DIR=".fizzy"
FIZZY_CONFIG_FILE="config.json"
FIZZY_CREDENTIALS_FILE="credentials.json"
FIZZY_CLIENT_FILE="client.json"
FIZZY_ACCOUNTS_FILE="accounts.json"


# Config Loading

declare -A _FIZZY_CONFIG

_load_config_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    debug "Loading config from $file"
    while IFS='=' read -r key value; do
      _FIZZY_CONFIG["$key"]="$value"
    done < <(jq -r 'to_entries | .[] | "\(.key)=\(.value)"' "$file" 2>/dev/null || true)
  fi
}

load_config() {
  _FIZZY_CONFIG=()

  # Layer 1: System-wide config
  _load_config_file "$FIZZY_SYSTEM_CONFIG_DIR/$FIZZY_CONFIG_FILE"

  # Layer 2: User/global config
  _load_config_file "$FIZZY_GLOBAL_CONFIG_DIR/$FIZZY_CONFIG_FILE"

  # Layer 3: Git repo root config (if in a git repo)
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [[ -n "$git_root" ]] && [[ -f "$git_root/$FIZZY_LOCAL_CONFIG_DIR/$FIZZY_CONFIG_FILE" ]]; then
    _load_config_file "$git_root/$FIZZY_LOCAL_CONFIG_DIR/$FIZZY_CONFIG_FILE"
  fi

  # Layer 4: Local config (walk up directory tree, skip git root if already loaded)
  local dir="$PWD"
  local local_configs=()
  while [[ "$dir" != "/" ]]; do
    local config_path="$dir/$FIZZY_LOCAL_CONFIG_DIR/$FIZZY_CONFIG_FILE"
    # Skip if this is the git root (already loaded above)
    if [[ -f "$config_path" ]] && [[ "$dir" != "$git_root" ]]; then
      local_configs+=("$config_path")
    fi
    dir="$(dirname "$dir")"
  done

  # Apply local configs from root to current (so closer overrides)
  for ((i=${#local_configs[@]}-1; i>=0; i--)); do
    _load_config_file "${local_configs[$i]}"
  done

  # Layer 5: Environment variables
  # Note: FIZZY_BASE_URL is handled separately in _update_base_url_from_config
  # because core.sh sets a default before we can capture the original env value
  [[ -n "${FIZZY_ACCOUNT_SLUG:-}" ]] && _FIZZY_CONFIG["account_slug"]="$FIZZY_ACCOUNT_SLUG" || true
  [[ -n "${FIZZY_BOARD_ID:-}" ]] && _FIZZY_CONFIG["board_id"]="$FIZZY_BOARD_ID" || true
  [[ -n "${FIZZY_COLUMN_ID:-}" ]] && _FIZZY_CONFIG["column_id"]="$FIZZY_COLUMN_ID" || true
  [[ -n "${FIZZY_ACCESS_TOKEN:-}" ]] && _FIZZY_CONFIG["access_token"]="$FIZZY_ACCESS_TOKEN" || true

  # Layer 6: Command-line flags (already handled in global flag parsing)
  [[ -n "${FIZZY_ACCOUNT:-}" ]] && _FIZZY_CONFIG["account_slug"]="$FIZZY_ACCOUNT" || true
  [[ -n "${FIZZY_BOARD:-}" ]] && _FIZZY_CONFIG["board_id"]="$FIZZY_BOARD" || true
}

get_config() {
  local key="$1"
  local default="${2:-}"
  echo "${_FIZZY_CONFIG[$key]:-$default}"
}

has_config() {
  local key="$1"
  [[ -n "${_FIZZY_CONFIG[$key]:-}" ]]
}


# Config Writing

ensure_global_config_dir() {
  mkdir -p "$FIZZY_GLOBAL_CONFIG_DIR"
}

ensure_local_config_dir() {
  mkdir -p "$FIZZY_LOCAL_CONFIG_DIR"
}

set_global_config() {
  local key="$1"
  local value="$2"

  ensure_global_config_dir
  local file="$FIZZY_GLOBAL_CONFIG_DIR/$FIZZY_CONFIG_FILE"

  if [[ -f "$file" ]]; then
    local tmp
    tmp=$(mktemp)
    jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$file" > "$tmp"
    mv "$tmp" "$file"
  else
    jq -n --arg key "$key" --arg value "$value" '{($key): $value}' > "$file"
  fi

  _FIZZY_CONFIG["$key"]="$value"
}

set_local_config() {
  local key="$1"
  local value="$2"

  ensure_local_config_dir
  local file="$FIZZY_LOCAL_CONFIG_DIR/$FIZZY_CONFIG_FILE"

  if [[ -f "$file" ]]; then
    local tmp
    tmp=$(mktemp)
    jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$file" > "$tmp"
    mv "$tmp" "$file"
  else
    jq -n --arg key "$key" --arg value "$value" '{($key): $value}' > "$file"
  fi

  _FIZZY_CONFIG["$key"]="$value"
}

unset_config() {
  local key="$1"
  local scope="${2:---local}"

  local file
  if [[ "$scope" == "--global" ]]; then
    file="$FIZZY_GLOBAL_CONFIG_DIR/$FIZZY_CONFIG_FILE"
  else
    file="$FIZZY_LOCAL_CONFIG_DIR/$FIZZY_CONFIG_FILE"
  fi

  if [[ -f "$file" ]]; then
    local tmp
    tmp=$(mktemp)
    jq --arg key "$key" 'del(.[$key])' "$file" > "$tmp"
    mv "$tmp" "$file"
  fi

  unset "_FIZZY_CONFIG[$key]"
}


# Credentials

get_credentials_path() {
  echo "$FIZZY_GLOBAL_CONFIG_DIR/$FIZZY_CREDENTIALS_FILE"
}

load_credentials() {
  local file
  file=$(get_credentials_path)
  if [[ -f "$file" ]]; then
    cat "$file"
  else
    echo '{}'
  fi
}

save_credentials() {
  local json="$1"
  ensure_global_config_dir
  local file
  file=$(get_credentials_path)
  echo "$json" > "$file"
  chmod 600 "$file"
}

get_access_token() {
  if [[ -n "${FIZZY_ACCESS_TOKEN:-}" ]]; then
    echo "$FIZZY_ACCESS_TOKEN"
    return
  fi

  local creds
  creds=$(load_credentials)
  local token
  token=$(echo "$creds" | jq -r '.access_token // empty')

  if [[ -z "$token" ]]; then
    return 1
  fi

  echo "$token"
}

is_token_expired() {
  local creds
  creds=$(load_credentials)
  local expires_at
  expires_at=$(echo "$creds" | jq -r '.expires_at // "null"')

  # Long-lived tokens (null or 0 expires_at) never expire
  if [[ "$expires_at" == "null" ]] || [[ "$expires_at" == "0" ]]; then
    return 1  # Not expired
  fi

  local now
  now=$(date +%s)
  (( now > expires_at - 60 ))
}

get_token_scope() {
  local creds
  creds=$(load_credentials)
  local scope
  scope=$(echo "$creds" | jq -r '.scope // empty')

  if [[ -z "$scope" ]]; then
    echo "unknown"
    return 1
  fi

  echo "$scope"
}


# Account Management

get_account_slug() {
  if [[ -n "${FIZZY_ACCOUNT:-}" ]]; then
    echo "$FIZZY_ACCOUNT"
    return
  fi
  if [[ -n "${FIZZY_ACCOUNT_SLUG:-}" ]]; then
    echo "$FIZZY_ACCOUNT_SLUG"
    return
  fi
  get_config "account_slug"
}

get_board_id() {
  if [[ -n "${FIZZY_BOARD:-}" ]]; then
    echo "$FIZZY_BOARD"
    return
  fi
  if [[ -n "${FIZZY_BOARD_ID:-}" ]]; then
    echo "$FIZZY_BOARD_ID"
    return
  fi
  get_config "board_id"
}

get_column_id() {
  if [[ -n "${FIZZY_COLUMN_ID:-}" ]]; then
    echo "$FIZZY_COLUMN_ID"
    return
  fi
  get_config "column_id"
}

get_git_root() {
  git rev-parse --show-toplevel 2>/dev/null || true
}

load_accounts() {
  local file="$FIZZY_GLOBAL_CONFIG_DIR/$FIZZY_ACCOUNTS_FILE"
  if [[ -f "$file" ]]; then
    cat "$file"
  else
    echo '[]'
  fi
}

save_accounts() {
  local json="$1"
  ensure_global_config_dir
  echo "$json" > "$FIZZY_GLOBAL_CONFIG_DIR/$FIZZY_ACCOUNTS_FILE"
}


# Client Registration

get_client_path() {
  echo "$FIZZY_GLOBAL_CONFIG_DIR/$FIZZY_CLIENT_FILE"
}

load_client() {
  local file
  file=$(get_client_path)
  if [[ -f "$file" ]]; then
    cat "$file"
  else
    echo '{}'
  fi
}

save_client() {
  local json="$1"
  ensure_global_config_dir
  local file
  file=$(get_client_path)
  echo "$json" > "$file"
  chmod 600 "$file"
}

get_client_id() {
  local client
  client=$(load_client)
  echo "$client" | jq -r '.client_id // empty'
}

get_client_secret() {
  local client
  client=$(load_client)
  echo "$client" | jq -r '.client_secret // empty'
}


# Config Display

get_effective_config() {
  local result='{}'
  for key in "${!_FIZZY_CONFIG[@]}"; do
    if [[ "$key" == "access_token" ]] || [[ "$key" == "refresh_token" ]]; then
      result=$(echo "$result" | jq --arg key "$key" '.[$key] = "***"')
    else
      result=$(echo "$result" | jq --arg key "$key" --arg value "${_FIZZY_CONFIG[$key]}" '.[$key] = $value')
    fi
  done
  echo "$result"
}

get_config_source() {
  local key="$1"

  # Check flags first (highest priority)
  case "$key" in
    account_slug) [[ -n "${FIZZY_ACCOUNT:-}" ]] && echo "flag" && return ;;
    board_id) [[ -n "${FIZZY_BOARD:-}" ]] && echo "flag" && return ;;
  esac

  # Check environment variables
  case "$key" in
    account_slug) [[ -n "${FIZZY_ACCOUNT_SLUG:-}" ]] && echo "env" && return ;;
    board_id) [[ -n "${FIZZY_BOARD_ID:-}" ]] && echo "env" && return ;;
    column_id) [[ -n "${FIZZY_COLUMN_ID:-}" ]] && echo "env" && return ;;
    access_token) [[ -n "${FIZZY_ACCESS_TOKEN:-}" ]] && echo "env" && return ;;
  esac

  # Check local (cwd) config
  if [[ -f "$FIZZY_LOCAL_CONFIG_DIR/$FIZZY_CONFIG_FILE" ]]; then
    local local_value
    local_value=$(jq -r --arg key "$key" '.[$key] // empty' "$FIZZY_LOCAL_CONFIG_DIR/$FIZZY_CONFIG_FILE" 2>/dev/null)
    [[ -n "$local_value" ]] && echo "local (.fizzy/)" && return
  fi

  # Check git repo root config
  local git_root
  git_root=$(get_git_root)
  if [[ -n "$git_root" ]] && [[ -f "$git_root/$FIZZY_LOCAL_CONFIG_DIR/$FIZZY_CONFIG_FILE" ]]; then
    local repo_value
    repo_value=$(jq -r --arg key "$key" '.[$key] // empty' "$git_root/$FIZZY_LOCAL_CONFIG_DIR/$FIZZY_CONFIG_FILE" 2>/dev/null)
    [[ -n "$repo_value" ]] && echo "repo ($git_root/.fizzy/)" && return
  fi

  # Check user/global config
  if [[ -f "$FIZZY_GLOBAL_CONFIG_DIR/$FIZZY_CONFIG_FILE" ]]; then
    local global_value
    global_value=$(jq -r --arg key "$key" '.[$key] // empty' "$FIZZY_GLOBAL_CONFIG_DIR/$FIZZY_CONFIG_FILE" 2>/dev/null)
    [[ -n "$global_value" ]] && echo "user (~/.config/fizzy/)" && return
  fi

  # Check system-wide config
  if [[ -f "$FIZZY_SYSTEM_CONFIG_DIR/$FIZZY_CONFIG_FILE" ]]; then
    local system_value
    system_value=$(jq -r --arg key "$key" '.[$key] // empty' "$FIZZY_SYSTEM_CONFIG_DIR/$FIZZY_CONFIG_FILE" 2>/dev/null)
    [[ -n "$system_value" ]] && echo "system (/etc/fizzy/)" && return
  fi

  echo "unset"
}


# Initialize

load_config

# Update FIZZY_BASE_URL from full config hierarchy
# This should override the initial value from core.sh (which only reads global config)
# unless FIZZY_BASE_URL was explicitly set via environment variable
_update_base_url_from_config() {
  # If user explicitly set FIZZY_BASE_URL env var, respect it
  if [[ -n "${_FIZZY_BASE_URL_FROM_ENV:-}" ]]; then
    return
  fi

  # Otherwise, apply full config hierarchy (local > repo > global > system)
  local base_url
  base_url=$(get_config "base_url")
  if [[ -n "$base_url" ]]; then
    FIZZY_BASE_URL="$base_url"
  fi
}

_update_base_url_from_config
