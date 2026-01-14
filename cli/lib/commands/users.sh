#!/usr/bin/env bash
# users.sh - Identity and user management commands


# fizzy identity
# Show current identity and associated accounts

cmd_identity() {
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
    _identity_help
    return 0
  fi

  # Identity endpoint doesn't require account_slug
  local token
  token=$(ensure_auth)

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
    401|403)
      die "Authentication failed" $EXIT_AUTH "Run: fizzy auth login"
      ;;
    *)
      die "API error: HTTP $http_code" $EXIT_API
      ;;
  esac

  local accounts
  accounts=$(echo "$response" | jq '.accounts // []')
  local count
  count=$(echo "$accounts" | jq 'length')

  local summary="${count} account"
  [[ "$count" -ne 1 ]] && summary="${count} accounts"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "status" "fizzy auth status" "Auth status")"
  )

  output "$response" "$summary" "$breadcrumbs" "_identity_md"
}

_identity_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local accounts
  accounts=$(echo "$data" | jq -r '.accounts // []')
  local count
  count=$(echo "$accounts" | jq 'length')

  # Derive name/email from first account's user (API doesn't have top-level identity fields)
  local email name
  if [[ "$count" -gt 0 ]]; then
    name=$(echo "$accounts" | jq -r '.[0].user.name // "unknown"')
    email=$(echo "$accounts" | jq -r '.[0].user.email_address // "unknown"')
  else
    name="unknown"
    email="unknown"
  fi

  md_heading 2 "Identity"
  echo
  md_kv "Name" "$name" \
        "Email" "$email"
  echo

  if [[ "$count" -gt 0 ]]; then
    md_heading 3 "Accounts ($count)"
    echo
    echo "| Name | Slug | Role |"
    echo "|------|------|------|"
    echo "$accounts" | jq -r '.[] | "| \(.name) | \(.slug | ltrimstr("/")) | \(.user.role // "member") |"'
  else
    echo "No accounts found."
  fi

  echo
  md_breadcrumbs "$breadcrumbs"
}

_identity_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy identity",
      description: "Show current identity and associated accounts",
      usage: "fizzy identity"
    }'
  else
    cat <<'EOF'
## fizzy identity

Show current identity and associated accounts.

### Usage

    fizzy identity

### Output

Shows your email, name, and a table of accounts you have access to
with their names, slugs, and your role in each.

### Examples

    fizzy identity         Show identity info
EOF
  fi
}


# fizzy user show <id|email|name>

cmd_user() {
  local action="${1:-}"
  shift || true

  case "$action" in
    show) _user_show "$@" ;;
    update) _user_update "$@" ;;
    delete) _user_delete "$@" ;;
    --help|-h|"") _user_help ;;
    *)
      die "Unknown subcommand: user $action" $EXIT_USAGE \
        "Available: fizzy user show|update|delete"
      ;;
  esac
}

_user_show() {
  local show_help=false
  local user_ref=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy user show --help"
        ;;
      *)
        if [[ -z "$user_ref" ]]; then
          user_ref="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _user_show_help
    return 0
  fi

  if [[ -z "$user_ref" ]]; then
    die "User ID, email, or name required" $EXIT_USAGE \
      "Usage: fizzy user show <id|email|name>"
  fi

  local account_slug
  account_slug=$(get_account_slug)
  if [[ -z "$account_slug" ]]; then
    die "Account not configured" $EXIT_USAGE \
      "Run: fizzy config set account_slug <slug>"
  fi

  # Resolve user reference to ID
  local user_id
  user_id=$(resolve_user_id "$user_ref") || exit $?

  local response
  response=$(api_get "/users/$user_id")

  local user_name
  user_name=$(echo "$response" | jq -r '.name // "unknown"')

  local summary="User: $user_name"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "people" "fizzy people" "List users")" \
    "$(breadcrumb "update" "fizzy user update $user_id" "Update user")"
  )

  output "$response" "$summary" "$breadcrumbs" "_user_show_md"
}

_user_show_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local id name email role avatar_url
  id=$(echo "$data" | jq -r '.id')
  name=$(echo "$data" | jq -r '.name // "unknown"')
  email=$(echo "$data" | jq -r '.email_address // "unknown"')
  role=$(echo "$data" | jq -r '.role // "member"')
  avatar_url=$(echo "$data" | jq -r '.avatar_url // "none"')

  md_heading 2 "$name"
  echo
  md_kv "ID" "$id" \
        "Email" "$email" \
        "Role" "$role" \
        "Avatar" "$avatar_url"

  md_breadcrumbs "$breadcrumbs"
}

_user_show_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy user show",
      description: "Show user details",
      usage: "fizzy user show <id|email|name>",
      examples: [
        "fizzy user show abc123",
        "fizzy user show alice@example.com",
        "fizzy user show \"Alice Smith\""
      ]
    }'
  else
    cat <<'EOF'
## fizzy user show

Show user details.

### Usage

    fizzy user show <id|email|name>

### Arguments

The user can be specified by:
- ID (exact match)
- Email address
- Name (partial match supported)

### Examples

    fizzy user show abc123              By ID
    fizzy user show alice@example.com   By email
    fizzy user show "Alice Smith"       By name
EOF
  fi
}


# fizzy user update <id|email|name> [--name NAME] [--avatar PATH]

_user_update() {
  local show_help=false
  local user_ref=""
  local new_name=""
  local avatar_path=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      --name)
        if [[ -z "${2:-}" ]]; then
          die "--name requires a value" $EXIT_USAGE
        fi
        new_name="$2"
        shift 2
        ;;
      --avatar)
        if [[ -z "${2:-}" ]]; then
          die "--avatar requires a file path" $EXIT_USAGE
        fi
        avatar_path="$2"
        shift 2
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy user update --help"
        ;;
      *)
        if [[ -z "$user_ref" ]]; then
          user_ref="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _user_update_help
    return 0
  fi

  if [[ -z "$user_ref" ]]; then
    die "User ID, email, or name required" $EXIT_USAGE \
      "Usage: fizzy user update <id|email|name> [--name NAME] [--avatar PATH]"
  fi

  if [[ -z "$new_name" ]] && [[ -z "$avatar_path" ]]; then
    die "Nothing to update" $EXIT_USAGE \
      "Provide --name and/or --avatar"
  fi

  # Validate avatar file exists
  if [[ -n "$avatar_path" ]] && [[ ! -f "$avatar_path" ]]; then
    die "File not found: $avatar_path" $EXIT_USAGE
  fi

  local account_slug
  account_slug=$(get_account_slug)
  if [[ -z "$account_slug" ]]; then
    die "Account not configured" $EXIT_USAGE \
      "Run: fizzy config set account_slug <slug>"
  fi

  # Resolve user reference to ID
  local user_id
  user_id=$(resolve_user_id "$user_ref") || exit $?

  local token
  token=$(ensure_auth)

  local http_code

  if [[ -n "$avatar_path" ]]; then
    # Multipart upload for avatar
    local curl_args=(
      -s -w '\n%{http_code}'
      -X PATCH
      -H "Authorization: Bearer $token"
      -H "User-Agent: $FIZZY_USER_AGENT"
      -H "Accept: application/json"
    )

    if [[ -n "$new_name" ]]; then
      curl_args+=(--form-string "user[name]=$new_name")
    fi
    curl_args+=(-F "user[avatar]=@$avatar_path")
    curl_args+=("$FIZZY_BASE_URL/$account_slug/users/$user_id.json")

    local response
    api_multipart_request http_code response "${curl_args[@]}"
  else
    # JSON update for name only
    local body
    body=$(jq -n --arg name "$new_name" '{user: {name: $name}}')

    local response
    response=$(curl -s -w '\n%{http_code}' \
      -X PATCH \
      -H "Authorization: Bearer $token" \
      -H "User-Agent: $FIZZY_USER_AGENT" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$body" \
      "$FIZZY_BASE_URL/$account_slug/users/$user_id.json")
    http_code=$(echo "$response" | tail -n1)
  fi

  case "$http_code" in
    200|204) ;;
    401|403)
      die "Not authorized to update this user" $EXIT_FORBIDDEN
      ;;
    404)
      die "User not found: $user_ref" $EXIT_NOT_FOUND
      ;;
    422)
      die "Validation error" $EXIT_API "Check the provided values"
      ;;
    *)
      die "API error: HTTP $http_code" $EXIT_API
      ;;
  esac

  # Fetch updated user (204 returns no body)
  local updated_user
  updated_user=$(api_get "/users/$user_id")

  local user_name
  user_name=$(echo "$updated_user" | jq -r '.name // "unknown"')

  local summary="Updated user $user_name"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy user show $user_id" "View user")" \
    "$(breadcrumb "people" "fizzy people" "List users")"
  )

  output "$updated_user" "$summary" "$breadcrumbs" "_user_show_md"
}

_user_update_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy user update",
      description: "Update user profile",
      usage: "fizzy user update <id|email|name> [--name NAME] [--avatar PATH]",
      options: [
        {flag: "--name", description: "New display name"},
        {flag: "--avatar", description: "Path to avatar image file"}
      ],
      examples: [
        "fizzy user update abc123 --name \"New Name\"",
        "fizzy user update alice@example.com --avatar ~/photo.jpg"
      ]
    }'
  else
    cat <<'EOF'
## fizzy user update

Update user profile.

### Usage

    fizzy user update <id|email|name> [--name NAME] [--avatar PATH]

### Options

    --name NAME       New display name
    --avatar PATH     Path to avatar image file

### Examples

    fizzy user update abc123 --name "New Name"
    fizzy user update alice@example.com --avatar ~/photo.jpg
    fizzy user update "Alice" --name "Alice Smith" --avatar ~/alice.png
EOF
  fi
}


# fizzy user delete <id|email|name>

_user_delete() {
  local show_help=false
  local user_ref=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy user delete --help"
        ;;
      *)
        if [[ -z "$user_ref" ]]; then
          user_ref="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _user_delete_help
    return 0
  fi

  if [[ -z "$user_ref" ]]; then
    die "User ID, email, or name required" $EXIT_USAGE \
      "Usage: fizzy user delete <id|email|name>"
  fi

  local account_slug
  account_slug=$(get_account_slug)
  if [[ -z "$account_slug" ]]; then
    die "Account not configured" $EXIT_USAGE \
      "Run: fizzy config set account_slug <slug>"
  fi

  # Resolve user to get name for summary before deletion
  local user_id user_name
  user_id=$(resolve_user_id "$user_ref") || exit $?

  # Fetch user name before delete
  local user_data
  user_data=$(api_get "/users/$user_id" 2>/dev/null || echo '{}')
  user_name=$(echo "$user_data" | jq -r '.name // "unknown"')

  # DELETE returns 204
  api_delete "/users/$user_id" > /dev/null

  local summary="Deactivated user $user_name"

  local response
  response=$(jq -n --arg id "$user_id" --arg name "$user_name" \
    '{id: $id, name: $name, deactivated: true}')

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "people" "fizzy people" "List users")"
  )

  output "$response" "$summary" "$breadcrumbs" "_user_delete_md"
}

_user_delete_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local user_name
  user_name=$(echo "$data" | jq -r '.name // "unknown"')

  md_heading 2 "User Deactivated"
  echo
  echo "User **$user_name** has been deactivated."

  md_breadcrumbs "$breadcrumbs"
}

_user_delete_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy user delete",
      description: "Deactivate a user",
      usage: "fizzy user delete <id|email|name>",
      warning: "This deactivates the user from the account",
      examples: [
        "fizzy user delete abc123",
        "fizzy user delete alice@example.com"
      ]
    }'
  else
    cat <<'EOF'
## fizzy user delete

Deactivate a user from the account.

### Usage

    fizzy user delete <id|email|name>

### Warning

This deactivates the user's access to the account. The user's data
is preserved but they can no longer access the account.

### Examples

    fizzy user delete abc123
    fizzy user delete alice@example.com
    fizzy user delete "Alice Smith"
EOF
  fi
}


_user_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy user",
      description: "Manage users in the account",
      subcommands: [
        {name: "show", description: "Show user details"},
        {name: "update", description: "Update user profile"},
        {name: "delete", description: "Deactivate a user"}
      ]
    }'
  else
    cat <<'EOF'
## fizzy user

Manage users in the account.

### Subcommands

    show <id|email|name>              Show user details
    update <id|email|name> [options]  Update user profile
    delete <id|email|name>            Deactivate a user

### Examples

    fizzy user show alice@example.com
    fizzy user update abc123 --name "New Name"
    fizzy user delete "Former Employee"
EOF
  fi
}
