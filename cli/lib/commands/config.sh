#!/usr/bin/env bash
# config.sh - Configuration management commands


# fizzy config [subcommand] [options]
# Manage configuration settings

cmd_config() {
  local subcommand=""
  local show_help=false

  if [[ $# -eq 0 ]]; then
    _config_list
    return
  fi

  case "$1" in
    --help|-h)
      _config_help
      return
      ;;
    list)
      shift
      _config_list "$@"
      ;;
    get)
      shift
      _config_get "$@"
      ;;
    set)
      shift
      _config_set "$@"
      ;;
    unset)
      shift
      _config_unset "$@"
      ;;
    path)
      shift
      _config_path "$@"
      ;;
    *)
      die "Unknown subcommand: $1" $EXIT_USAGE "Run: fizzy config --help"
      ;;
  esac
}


_config_list() {
  local show_sources=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sources)
        show_sources=true
        shift
        ;;
      *)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy config --help"
        ;;
    esac
  done

  local config_data
  config_data=$(get_effective_config)

  local summary="Configuration"
  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "get" "fizzy config get <key>" "Get specific value")" \
    "$(breadcrumb "set" "fizzy config set <key> <value>" "Set a value")" \
    "$(breadcrumb "path" "fizzy config path" "Show config file paths")"
  )

  if [[ "$show_sources" == "true" ]]; then
    # Build JSON with sources
    local result='{}'
    for key in $(echo "$config_data" | jq -r 'keys[]'); do
      local value source
      value=$(echo "$config_data" | jq -r --arg k "$key" '.[$k]')
      source=$(get_config_source "$key")
      result=$(echo "$result" | jq --arg k "$key" --arg v "$value" --arg s "$source" \
        '.[$k] = {value: $v, source: $s}')
    done
    config_data="$result"
  fi

  # Build context with show_sources flag for markdown renderer
  local context="{}"
  if [[ "$show_sources" == "true" ]]; then
    context='{"show_sources": true}'
  fi

  output "$config_data" "$summary" "$breadcrumbs" "_config_list_md" "$context"
}

_config_list_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"
  # Note: Use quoted default to avoid bash parsing issue with closing braces
  local context="${4:-"{}"}"

  local show_sources
  show_sources=$(echo "$context" | jq -r '.show_sources // false')

  md_heading 2 "Configuration"
  echo

  local count
  count=$(echo "$data" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No configuration set."
    echo
  elif [[ "$show_sources" == "true" ]]; then
    echo "| Key | Value | Source |"
    echo "|-----|-------|--------|"
    echo "$data" | jq -r 'to_entries | .[] | "| \(.key) | \(.value.value) | \(.value.source) |"'
    echo
  else
    echo "| Key | Value |"
    echo "|-----|-------|"
    echo "$data" | jq -r 'to_entries | .[] | "| \(.key) | \(.value) |"'
    echo
  fi

  md_breadcrumbs "$breadcrumbs"
}


_config_get() {
  if [[ $# -eq 0 ]]; then
    die "Key required" $EXIT_USAGE "Usage: fizzy config get <key>"
  fi

  local key="$1"
  local show_source=false
  shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source)
        show_source=true
        shift
        ;;
      *)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy config --help"
        ;;
    esac
  done

  local value
  value=$(get_config "$key")

  if [[ -z "$value" ]]; then
    die "Key not found: $key" $EXIT_NOT_FOUND "Run: fizzy config list"
  fi

  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    if [[ "$show_source" == "true" ]]; then
      local source
      source=$(get_config_source "$key")
      jq -n --arg k "$key" --arg v "$value" --arg s "$source" \
        '{key: $k, value: $v, source: $s}'
    else
      jq -n --arg k "$key" --arg v "$value" '{key: $k, value: $v}'
    fi
  else
    if [[ "$show_source" == "true" ]]; then
      local source
      source=$(get_config_source "$key")
      echo "$value  # from $source"
    else
      echo "$value"
    fi
  fi
}


_config_set() {
  local scope="--local"
  local key=""
  local value=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --global|-g)
        scope="--global"
        shift
        ;;
      --local|-l)
        scope="--local"
        shift
        ;;
      *)
        if [[ -z "$key" ]]; then
          key="$1"
        elif [[ -z "$value" ]]; then
          value="$1"
        else
          die "Too many arguments" $EXIT_USAGE "Usage: fizzy config set [--global|--local] <key> <value>"
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$key" ]]; then
    die "Key required" $EXIT_USAGE "Usage: fizzy config set [--global|--local] <key> <value>"
  fi

  if [[ -z "$value" ]]; then
    die "Value required" $EXIT_USAGE "Usage: fizzy config set [--global|--local] <key> <value>"
  fi

  if [[ "$scope" == "--global" ]]; then
    set_global_config "$key" "$value"
    info "Set $key = $value (global)"
  else
    set_local_config "$key" "$value"
    info "Set $key = $value (local)"
  fi
}


_config_unset() {
  local scope="--local"
  local key=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --global|-g)
        scope="--global"
        shift
        ;;
      --local|-l)
        scope="--local"
        shift
        ;;
      *)
        if [[ -z "$key" ]]; then
          key="$1"
        else
          die "Too many arguments" $EXIT_USAGE "Usage: fizzy config unset [--global|--local] <key>"
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$key" ]]; then
    die "Key required" $EXIT_USAGE "Usage: fizzy config unset [--global|--local] <key>"
  fi

  unset_config "$key" "$scope"

  local scope_name="local"
  [[ "$scope" == "--global" ]] && scope_name="global"
  info "Unset $key ($scope_name)"
}


_config_path() {
  local format
  format=$(get_format)

  local git_root
  git_root=$(get_git_root)

  local paths
  paths=$(jq -n \
    --arg system "$FIZZY_SYSTEM_CONFIG_DIR/$FIZZY_CONFIG_FILE" \
    --arg global "$FIZZY_GLOBAL_CONFIG_DIR/$FIZZY_CONFIG_FILE" \
    --arg repo "${git_root:+$git_root/$FIZZY_LOCAL_CONFIG_DIR/$FIZZY_CONFIG_FILE}" \
    --arg local "$PWD/$FIZZY_LOCAL_CONFIG_DIR/$FIZZY_CONFIG_FILE" \
    --arg credentials "$FIZZY_GLOBAL_CONFIG_DIR/$FIZZY_CREDENTIALS_FILE" \
    '{
      system: $system,
      global: $global,
      repo: (if $repo == "" then null else $repo end),
      local: $local,
      credentials: $credentials
    }')

  if [[ "$format" == "json" ]]; then
    echo "$paths"
  else
    md_heading 2 "Config Paths"
    echo
    echo "| Scope | Path | Exists |"
    echo "|-------|------|--------|"

    local system_path global_path repo_path local_path creds_path
    system_path="$FIZZY_SYSTEM_CONFIG_DIR/$FIZZY_CONFIG_FILE"
    global_path="$FIZZY_GLOBAL_CONFIG_DIR/$FIZZY_CONFIG_FILE"
    repo_path="${git_root:+$git_root/$FIZZY_LOCAL_CONFIG_DIR/$FIZZY_CONFIG_FILE}"
    local_path="$PWD/$FIZZY_LOCAL_CONFIG_DIR/$FIZZY_CONFIG_FILE"
    creds_path="$FIZZY_GLOBAL_CONFIG_DIR/$FIZZY_CREDENTIALS_FILE"

    _config_path_row "system" "$system_path"
    _config_path_row "global" "$global_path"
    [[ -n "$repo_path" ]] && _config_path_row "repo" "$repo_path"
    _config_path_row "local" "$local_path"
    _config_path_row "credentials" "$creds_path"
    echo
  fi
}

_config_path_row() {
  local scope="$1"
  local path="$2"
  local exists="No"
  [[ -f "$path" ]] && exists="Yes"
  echo "| $scope | $path | $exists |"
}


_config_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy config",
      description: "Manage configuration settings",
      subcommands: [
        {name: "list", description: "List all configuration (default)"},
        {name: "get", description: "Get a configuration value"},
        {name: "set", description: "Set a configuration value"},
        {name: "unset", description: "Remove a configuration value"},
        {name: "path", description: "Show configuration file paths"}
      ],
      options: [
        {flag: "--global, -g", description: "Use global (~/.config/fizzy/) config"},
        {flag: "--local, -l", description: "Use local (.fizzy/) config (default)"},
        {flag: "--sources", description: "Show where each value comes from (list)"},
        {flag: "--source", description: "Show source for value (get)"}
      ],
      keys: [
        {name: "account_slug", description: "Default account ID"},
        {name: "board_id", description: "Default board ID"},
        {name: "column_id", description: "Default column ID"},
        {name: "base_url", description: "Fizzy API base URL"}
      ],
      examples: [
        "fizzy config",
        "fizzy config list --sources",
        "fizzy config get account_slug",
        "fizzy config set account_slug 897362094",
        "fizzy config set --global account_slug 897362094",
        "fizzy config unset board_id",
        "fizzy config path"
      ]
    }'
  else
    cat <<'EOF'
## fizzy config

Manage configuration settings.

### Usage

    fizzy config                    List all configuration
    fizzy config list [--sources]   List config (optionally with sources)
    fizzy config get <key>          Get a value
    fizzy config set <key> <value>  Set a value
    fizzy config unset <key>        Remove a value
    fizzy config path               Show config file paths

### Options

    --global, -g    Use global (~/.config/fizzy/) config
    --local, -l     Use local (.fizzy/) config (default)
    --sources       Show where each value comes from
    --source        Show source for a specific value

### Configuration Keys

    account_slug    Default account ID
    board_id        Default board ID
    column_id       Default column ID
    base_url        Fizzy API base URL

### Config Hierarchy (later overrides earlier)

    1. /etc/fizzy/config.json       System-wide
    2. ~/.config/fizzy/config.json  User/global
    3. <git-root>/.fizzy/config.json  Repository
    4. <cwd>/.fizzy/config.json     Local
    5. Environment variables        FIZZY_ACCOUNT_SLUG, etc.
    6. Command-line flags           --account, --board

### Examples

    fizzy config                           List all config
    fizzy config list --sources            Show value sources
    fizzy config get account_slug          Get account
    fizzy config set account_slug 897362094
    fizzy config set --global base_url https://fizzy.example.com
    fizzy config unset board_id
EOF
  fi
}
