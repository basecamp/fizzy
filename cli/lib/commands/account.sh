#!/usr/bin/env bash
# account.sh - Account management commands


# fizzy account <subcommand>
# Manage account settings

cmd_account() {
  case "${1:-}" in
    show)
      shift
      _account_show "$@"
      ;;
    update)
      shift
      _account_update "$@"
      ;;
    entropy)
      shift
      _account_entropy "$@"
      ;;
    join-code)
      shift
      _account_join_code "$@"
      ;;
    export)
      shift
      _account_export "$@"
      ;;
    --help|-h|"")
      _account_help
      ;;
    *)
      die "Unknown subcommand: account ${1:-}" $EXIT_USAGE \
        "Available: fizzy account show|update|entropy|join-code|export"
      ;;
  esac
}

_account_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy account",
      description: "Manage account settings",
      subcommands: [
        {name: "show", description: "Show account details"},
        {name: "update", description: "Update account name"},
        {name: "entropy", description: "Set auto-postpone period"},
        {name: "join-code", description: "Manage team join code"},
        {name: "export", description: "Request data export"}
      ],
      examples: [
        "fizzy account show",
        "fizzy account update --name \"New Name\"",
        "fizzy account entropy --period 14",
        "fizzy account join-code show",
        "fizzy account export"
      ]
    }'
  else
    cat <<'EOF'
## fizzy account

Manage account settings.

### Subcommands

    show                    Show account details
    update --name NAME      Update account name
    entropy --period DAYS   Set auto-postpone period (days)
    join-code <action>      Manage team join code
    export                  Request data export

### Examples

    fizzy account show
    fizzy account update --name "New Name"
    fizzy account entropy --period 14
    fizzy account join-code show
    fizzy account join-code reset
    fizzy account export
EOF
  fi
}


# fizzy account show

_account_show() {
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _account_show_help
    return 0
  fi

  local account_slug
  account_slug=$(get_account_slug)
  if [[ -z "$account_slug" ]]; then
    die "Account not configured" $EXIT_USAGE \
      "Run: fizzy config set account_slug <slug>"
  fi

  # Fetch account settings - returns HTML but we can get account from identity
  local token
  token=$(ensure_auth)

  # Get identity which includes account info
  local response
  response=$(curl -s -w '\n%{http_code}' \
    -H "Authorization: Bearer $token" \
    -H "User-Agent: $FIZZY_USER_AGENT" \
    -H "Accept: application/json" \
    "$FIZZY_BASE_URL/my/identity.json")

  local http_code
  http_code=$(echo "$response" | tail -n1)
  response=$(echo "$response" | sed '$d')

  case "$http_code" in
    200) ;;
    *)
      die "API error: HTTP $http_code" $EXIT_API
      ;;
  esac

  # Find current account in the list
  local account_data
  account_data=$(echo "$response" | jq --arg slug "/$account_slug" '.accounts[] | select(.slug == $slug) // empty')

  if [[ -z "$account_data" ]]; then
    die "Account not found: $account_slug" $EXIT_NOT_FOUND
  fi

  local account_name
  account_name=$(echo "$account_data" | jq -r '.name // "unknown"')

  local summary="Account: $account_name"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "update" "fizzy account update --name \"name\"" "Update name")" \
    "$(breadcrumb "entropy" "fizzy account entropy --period 14" "Set entropy")" \
    "$(breadcrumb "join-code" "fizzy account join-code show" "View join code")"
  )

  output "$account_data" "$summary" "$breadcrumbs" "_account_show_md"
}

_account_show_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local name slug
  name=$(echo "$data" | jq -r '.name // "unknown"')
  slug=$(echo "$data" | jq -r '.slug // "unknown" | ltrimstr("/")')

  local user_role
  user_role=$(echo "$data" | jq -r '.user.role // "member"')

  md_heading 2 "Account: $name"
  echo
  md_kv "Slug" "$slug" \
        "Your Role" "$user_role"

  md_breadcrumbs "$breadcrumbs"
}

_account_show_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy account show",
      description: "Show account details",
      usage: "fizzy account show"
    }'
  else
    cat <<'EOF'
## fizzy account show

Show account details.

### Usage

    fizzy account show
EOF
  fi
}


# fizzy account update --name NAME

_account_update() {
  local show_help=false
  local new_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name|-n)
        if [[ -z "${2:-}" ]]; then
          die "--name requires a value" $EXIT_USAGE
        fi
        new_name="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      *)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy account update --help"
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _account_update_help
    return 0
  fi

  if [[ -z "$new_name" ]]; then
    die "Nothing to update" $EXIT_USAGE "Provide --name"
  fi

  local account_slug
  account_slug=$(get_account_slug)
  if [[ -z "$account_slug" ]]; then
    die "Account not configured" $EXIT_USAGE \
      "Run: fizzy config set account_slug <slug>"
  fi

  local token
  token=$(ensure_auth)

  local body
  body=$(jq -n --arg name "$new_name" '{account: {name: $name}}')

  local response
  response=$(curl -s -w '\n%{http_code}' \
    -X PATCH \
    -H "Authorization: Bearer $token" \
    -H "User-Agent: $FIZZY_USER_AGENT" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$body" \
    "$FIZZY_BASE_URL/$account_slug/account/settings.json")

  local http_code
  http_code=$(echo "$response" | tail -n1)

  case "$http_code" in
    200|204|302) ;;
    401|403)
      die "Not authorized" $EXIT_FORBIDDEN "Only admins can update account"
      ;;
    *)
      die "API error: HTTP $http_code" $EXIT_API
      ;;
  esac

  local result
  result=$(jq -n --arg name "$new_name" --arg slug "$account_slug" \
    '{name: $name, slug: $slug, updated: true}')

  local summary="Updated account name to $new_name"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy account show" "View account")"
  )

  output "$result" "$summary" "$breadcrumbs" "_account_updated_md"
}

_account_updated_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local name
  name=$(echo "$data" | jq -r '.name // "unknown"')

  md_heading 2 "Account Updated"
  echo
  echo "Account name changed to **$name**."

  md_breadcrumbs "$breadcrumbs"
}

_account_update_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy account update",
      description: "Update account name",
      usage: "fizzy account update --name NAME",
      options: [
        {flag: "--name, -n", description: "New account name"}
      ],
      examples: [
        "fizzy account update --name \"My Team\""
      ]
    }'
  else
    cat <<'EOF'
## fizzy account update

Update account name.

### Usage

    fizzy account update --name NAME

### Options

    --name, -n   New account name

### Examples

    fizzy account update --name "My Team"
EOF
  fi
}


# fizzy account entropy --period DAYS

_account_entropy() {
  local show_help=false
  local period=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --period|-p)
        if [[ -z "${2:-}" ]]; then
          die "--period requires a value" $EXIT_USAGE
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
          die "--period must be a positive integer (days)" $EXIT_USAGE
        fi
        period="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      *)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy account entropy --help"
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _account_entropy_help
    return 0
  fi

  if [[ -z "$period" ]]; then
    die "Period required" $EXIT_USAGE "Usage: fizzy account entropy --period DAYS"
  fi

  local account_slug
  account_slug=$(get_account_slug)
  if [[ -z "$account_slug" ]]; then
    die "Account not configured" $EXIT_USAGE \
      "Run: fizzy config set account_slug <slug>"
  fi

  local token
  token=$(ensure_auth)

  local body
  body=$(jq -n --argjson period "$period" '{entropy: {auto_postpone_period: $period}}')

  local response
  response=$(curl -s -w '\n%{http_code}' \
    -X PATCH \
    -H "Authorization: Bearer $token" \
    -H "User-Agent: $FIZZY_USER_AGENT" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$body" \
    "$FIZZY_BASE_URL/$account_slug/account/entropy.json")

  local http_code
  http_code=$(echo "$response" | tail -n1)

  case "$http_code" in
    200|204|302) ;;
    401|403)
      die "Not authorized" $EXIT_FORBIDDEN "Only admins can update entropy"
      ;;
    *)
      die "API error: HTTP $http_code" $EXIT_API
      ;;
  esac

  local result
  result=$(jq -n --argjson period "$period" '{auto_postpone_period: $period, updated: true}')

  local summary="Set auto-postpone period to $period days"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy account show" "View account")"
  )

  output "$result" "$summary" "$breadcrumbs" "_account_entropy_md"
}

_account_entropy_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local period
  period=$(echo "$data" | jq -r '.auto_postpone_period // "unknown"')

  md_heading 2 "Entropy Updated"
  echo
  echo "Cards will auto-postpone after **$period days** of inactivity."

  md_breadcrumbs "$breadcrumbs"
}

_account_entropy_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy account entropy",
      description: "Set account auto-postpone period",
      usage: "fizzy account entropy --period DAYS",
      options: [
        {flag: "--period, -p", description: "Days before cards auto-postpone"}
      ],
      notes: [
        "Cards without activity will automatically move to Not Now",
        "Set to 0 to disable auto-postponement"
      ],
      examples: [
        "fizzy account entropy --period 14",
        "fizzy account entropy --period 30"
      ]
    }'
  else
    cat <<'EOF'
## fizzy account entropy

Set account auto-postpone period.

### Usage

    fizzy account entropy --period DAYS

### Options

    --period, -p   Days before cards auto-postpone

### Notes

Cards without activity will automatically move to "Not Now" after
the specified number of days. Set to 0 to disable.

### Examples

    fizzy account entropy --period 14
    fizzy account entropy --period 30
EOF
  fi
}


# fizzy account join-code <show|update|reset>

_account_join_code() {
  local action="${1:-show}"
  shift || true

  case "$action" in
    show)
      _account_join_code_show "$@"
      ;;
    update)
      _account_join_code_update "$@"
      ;;
    reset)
      _account_join_code_reset "$@"
      ;;
    --help|-h)
      _account_join_code_help
      ;;
    *)
      die "Unknown action: $action" $EXIT_USAGE \
        "Available: show, update, reset"
      ;;
  esac
}

_account_join_code_show() {
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _account_join_code_help
    return 0
  fi

  local account_slug
  account_slug=$(get_account_slug)
  if [[ -z "$account_slug" ]]; then
    die "Account not configured" $EXIT_USAGE \
      "Run: fizzy config set account_slug <slug>"
  fi

  local token
  token=$(ensure_auth)

  local response
  response=$(curl -s -w '\n%{http_code}' \
    -H "Authorization: Bearer $token" \
    -H "User-Agent: $FIZZY_USER_AGENT" \
    -H "Accept: application/json" \
    "$FIZZY_BASE_URL/$account_slug/account/join_code.json")

  local http_code
  http_code=$(echo "$response" | tail -n1)
  response=$(echo "$response" | sed '$d')

  case "$http_code" in
    200) ;;
    401|403)
      die "Not authorized" $EXIT_FORBIDDEN
      ;;
    *)
      die "API error: HTTP $http_code" $EXIT_API
      ;;
  esac

  local summary="Join code"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "reset" "fizzy account join-code reset" "Reset code")" \
    "$(breadcrumb "update" "fizzy account join-code update --limit 10" "Set limit")"
  )

  output "$response" "$summary" "$breadcrumbs" "_account_join_code_md"
}

_account_join_code_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local code usage_limit usage_count
  code=$(echo "$data" | jq -r '.code // "unknown"')
  usage_limit=$(echo "$data" | jq -r '.usage_limit // "unlimited"')
  usage_count=$(echo "$data" | jq -r '.usage_count // 0')

  md_heading 2 "Join Code"
  echo
  md_kv "Code" "$code" \
        "Usage Limit" "$usage_limit" \
        "Times Used" "$usage_count"
  echo
  echo "Share this code to invite people to join your account."

  md_breadcrumbs "$breadcrumbs"
}

_account_join_code_update() {
  local show_help=false
  local limit=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --limit|-l)
        if [[ -z "${2:-}" ]]; then
          die "--limit requires a value" $EXIT_USAGE
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
          die "--limit must be a positive integer" $EXIT_USAGE
        fi
        limit="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      *)
        die "Unknown option: $1" $EXIT_USAGE
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _account_join_code_help
    return 0
  fi

  if [[ -z "$limit" ]]; then
    die "Limit required" $EXIT_USAGE "Usage: fizzy account join-code update --limit NUMBER"
  fi

  local account_slug
  account_slug=$(get_account_slug)
  if [[ -z "$account_slug" ]]; then
    die "Account not configured" $EXIT_USAGE
  fi

  local token
  token=$(ensure_auth)

  local body
  body=$(jq -n --argjson limit "$limit" '{account_join_code: {usage_limit: $limit}}')

  local response
  response=$(curl -s -w '\n%{http_code}' \
    -X PATCH \
    -H "Authorization: Bearer $token" \
    -H "User-Agent: $FIZZY_USER_AGENT" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$body" \
    "$FIZZY_BASE_URL/$account_slug/account/join_code.json")

  local http_code
  http_code=$(echo "$response" | tail -n1)

  case "$http_code" in
    200|204|302) ;;
    401|403)
      die "Not authorized" $EXIT_FORBIDDEN "Only admins can update join code"
      ;;
    *)
      die "API error: HTTP $http_code" $EXIT_API
      ;;
  esac

  local result
  result=$(jq -n --argjson limit "$limit" '{usage_limit: $limit, updated: true}')

  local summary="Updated join code usage limit to $limit"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy account join-code show" "View code")"
  )

  output "$result" "$summary" "$breadcrumbs" "_account_join_code_updated_md"
}

_account_join_code_updated_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local limit
  limit=$(echo "$data" | jq -r '.usage_limit // "unknown"')

  md_heading 2 "Join Code Updated"
  echo
  echo "Usage limit set to **$limit**."

  md_breadcrumbs "$breadcrumbs"
}

_account_join_code_reset() {
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _account_join_code_help
    return 0
  fi

  local account_slug
  account_slug=$(get_account_slug)
  if [[ -z "$account_slug" ]]; then
    die "Account not configured" $EXIT_USAGE
  fi

  local token
  token=$(ensure_auth)

  local response
  response=$(curl -s -w '\n%{http_code}' \
    -X DELETE \
    -H "Authorization: Bearer $token" \
    -H "User-Agent: $FIZZY_USER_AGENT" \
    -H "Accept: application/json" \
    "$FIZZY_BASE_URL/$account_slug/account/join_code.json")

  local http_code
  http_code=$(echo "$response" | tail -n1)

  case "$http_code" in
    200|204|302) ;;
    401|403)
      die "Not authorized" $EXIT_FORBIDDEN "Only admins can reset join code"
      ;;
    *)
      die "API error: HTTP $http_code" $EXIT_API
      ;;
  esac

  local result='{"reset": true}'

  local summary="Join code reset"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy account join-code show" "View new code")"
  )

  output "$result" "$summary" "$breadcrumbs" "_account_join_code_reset_md"
}

_account_join_code_reset_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  md_heading 2 "Join Code Reset"
  echo
  echo "The join code has been reset. Previous code is no longer valid."

  md_breadcrumbs "$breadcrumbs"
}

_account_join_code_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy account join-code",
      description: "Manage team join code",
      usage: "fizzy account join-code <show|update|reset>",
      actions: [
        {name: "show", description: "Show current join code"},
        {name: "update --limit N", description: "Set usage limit"},
        {name: "reset", description: "Generate new code (invalidates old)"}
      ],
      examples: [
        "fizzy account join-code show",
        "fizzy account join-code update --limit 10",
        "fizzy account join-code reset"
      ]
    }'
  else
    cat <<'EOF'
## fizzy account join-code

Manage team join code.

### Usage

    fizzy account join-code <show|update|reset>

### Actions

    show              Show current join code
    update --limit N  Set usage limit
    reset             Generate new code (invalidates old)

### Examples

    fizzy account join-code show
    fizzy account join-code update --limit 10
    fizzy account join-code reset
EOF
  fi
}


# fizzy account export

_account_export() {
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _account_export_help
    return 0
  fi

  local account_slug
  account_slug=$(get_account_slug)
  if [[ -z "$account_slug" ]]; then
    die "Account not configured" $EXIT_USAGE \
      "Run: fizzy config set account_slug <slug>"
  fi

  local token
  token=$(ensure_auth)

  local response
  response=$(curl -s -w '\n%{http_code}' \
    -X POST \
    -H "Authorization: Bearer $token" \
    -H "User-Agent: $FIZZY_USER_AGENT" \
    -H "Accept: application/json" \
    "$FIZZY_BASE_URL/$account_slug/account/exports.json")

  local http_code
  http_code=$(echo "$response" | tail -n1)

  case "$http_code" in
    200|201|202|302) ;;
    429)
      die "Export limit exceeded" $EXIT_API \
        "You have reached the maximum number of exports"
      ;;
    401|403)
      die "Not authorized" $EXIT_FORBIDDEN
      ;;
    *)
      die "API error: HTTP $http_code" $EXIT_API
      ;;
  esac

  local result='{"requested": true}'

  local summary="Export requested"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy account show" "View account")"
  )

  output "$result" "$summary" "$breadcrumbs" "_account_export_md"
}

_account_export_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  md_heading 2 "Export Requested"
  echo
  echo "Your data export has been queued. You will receive an email"
  echo "when the export is ready for download."

  md_breadcrumbs "$breadcrumbs"
}

_account_export_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy account export",
      description: "Request account data export",
      usage: "fizzy account export",
      notes: [
        "Creates a background job to export all account data",
        "You will receive an email when export is ready",
        "Limited to 10 concurrent exports per user"
      ]
    }'
  else
    cat <<'EOF'
## fizzy account export

Request account data export.

### Usage

    fizzy account export

### Notes

- Creates a background job to export all account data
- You will receive an email when export is ready
- Limited to 10 concurrent exports per user
EOF
  fi
}
