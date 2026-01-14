#!/usr/bin/env bash
# webhooks.sh - Webhook management commands


# fizzy webhooks --board <board>
# List webhooks for a board

cmd_webhooks() {
  local board_id=""
  local show_help=false
  local page=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --board|-b|--in)
        if [[ -z "${2:-}" ]]; then
          die "--board requires a board name or ID" $EXIT_USAGE
        fi
        board_id="$2"
        shift 2
        ;;
      --page|-p)
        if [[ -z "${2:-}" ]]; then
          die "--page requires a value" $EXIT_USAGE
        fi
        page="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      *)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy webhooks --help"
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _webhooks_list_help
    return 0
  fi

  # Resolve board
  if [[ -z "$board_id" ]]; then
    board_id=$(get_board_id 2>/dev/null || true)
  fi
  if [[ -z "$board_id" ]]; then
    die "Board required" $EXIT_USAGE "Use --board or set default board"
  fi

  local resolved_board
  if resolved_board=$(resolve_board_id "$board_id"); then
    board_id="$resolved_board"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy boards"
  fi

  local path="/boards/$board_id/webhooks"
  if [[ -n "$page" ]]; then
    path="$path?page=$page"
  fi

  local response
  response=$(api_get "$path")

  local count
  count=$(echo "$response" | jq 'length')

  local summary="$count webhooks"
  [[ -n "$page" ]] && summary="$count webhooks (page $page)"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "create" "fizzy webhook create --board $board_id" "Create webhook")" \
    "$(breadcrumb "board" "fizzy show board $board_id" "View board")"
  )

  output "$response" "$summary" "$breadcrumbs" "_webhooks_md"
}

_webhooks_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  md_heading 2 "Webhooks ($summary)"

  local count
  count=$(echo "$data" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No webhooks found."
    echo
  else
    echo "| ID | Name | URL | Actions |"
    echo "|----|------|-----|---------|"
    echo "$data" | jq -r '.[] | "| \(.id) | \(.name) | \(.url | .[0:40])... | \(.subscribed_actions | length) |"'
    echo
  fi

  md_breadcrumbs "$breadcrumbs"
}

_webhooks_list_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy webhooks",
      description: "List webhooks for a board",
      usage: "fizzy webhooks --board <board>",
      options: [
        {flag: "--board, -b", description: "Board ID or name"},
        {flag: "--page", description: "Page number"}
      ],
      examples: [
        "fizzy webhooks --board \"My Board\""
      ]
    }'
  else
    cat <<'EOF'
## fizzy webhooks

List webhooks for a board.

### Usage

    fizzy webhooks --board <board>

### Options

    --board, -b   Board ID or name
    --page        Page number

### Examples

    fizzy webhooks --board "My Board"
EOF
  fi
}


# fizzy webhook <subcommand>
# Manage webhooks

cmd_webhook() {
  case "${1:-}" in
    create)
      shift
      _webhook_create "$@"
      ;;
    show)
      shift
      _webhook_show "$@"
      ;;
    update)
      shift
      _webhook_update "$@"
      ;;
    delete)
      shift
      _webhook_delete "$@"
      ;;
    --help|-h|"")
      _webhook_help
      ;;
    *)
      die "Unknown subcommand: webhook ${1:-}" $EXIT_USAGE \
        "Available: fizzy webhook create|show|update|delete"
      ;;
  esac
}

_webhook_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy webhook",
      description: "Manage webhooks",
      subcommands: [
        {name: "create", description: "Create a webhook"},
        {name: "show", description: "Show webhook details"},
        {name: "update", description: "Update a webhook"},
        {name: "delete", description: "Delete a webhook"}
      ],
      examples: [
        "fizzy webhook create --board \"My Board\" --name \"Slack\" --url \"https://...\" --actions card_published card_closed",
        "fizzy webhook show abc123 --board \"My Board\"",
        "fizzy webhook update abc123 --board \"My Board\" --name \"New Name\"",
        "fizzy webhook delete abc123 --board \"My Board\""
      ]
    }'
  else
    cat <<'EOF'
## fizzy webhook

Manage webhooks.

### Subcommands

    create   Create a webhook
    show     Show webhook details
    update   Update a webhook
    delete   Delete a webhook

### Examples

    fizzy webhook create --board "My Board" --name "Slack" --url "https://..." --actions card_published
    fizzy webhook show abc123 --board "My Board"
    fizzy webhook update abc123 --board "My Board" --name "New Name"
    fizzy webhook delete abc123 --board "My Board"
EOF
  fi
}


# fizzy webhook create --board <board> --name <name> --url <url> [--actions ...]

_webhook_create() {
  local board_id=""
  local name=""
  local url=""
  local actions=()
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --board|-b|--in)
        if [[ -z "${2:-}" ]]; then
          die "--board requires a board name or ID" $EXIT_USAGE
        fi
        board_id="$2"
        shift 2
        ;;
      --name|-n)
        if [[ -z "${2:-}" ]]; then
          die "--name requires a value" $EXIT_USAGE
        fi
        name="$2"
        shift 2
        ;;
      --url|-u)
        if [[ -z "${2:-}" ]]; then
          die "--url requires a value" $EXIT_USAGE
        fi
        url="$2"
        shift 2
        ;;
      --actions|-a)
        shift
        while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; do
          actions+=("$1")
          shift
        done
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      *)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy webhook create --help"
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _webhook_create_help
    return 0
  fi

  if [[ -z "$name" ]]; then
    die "Name required" $EXIT_USAGE "Use --name"
  fi

  if [[ -z "$url" ]]; then
    die "URL required" $EXIT_USAGE "Use --url"
  fi

  # Resolve board
  if [[ -z "$board_id" ]]; then
    board_id=$(get_board_id 2>/dev/null || true)
  fi
  if [[ -z "$board_id" ]]; then
    die "Board required" $EXIT_USAGE "Use --board or set default board"
  fi

  local resolved_board
  if resolved_board=$(resolve_board_id "$board_id"); then
    board_id="$resolved_board"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy boards"
  fi

  local token
  token=$(ensure_auth)

  local account_slug
  account_slug=$(get_account_slug)

  # Build form data
  local curl_args=(
    -s -w '\n%{http_code}'
    -X POST
    -H "Authorization: Bearer $token"
    -H "User-Agent: $FIZZY_USER_AGENT"
    -H "Accept: application/json"
  )

  curl_args+=(--form-string "webhook[name]=$name")
  curl_args+=(--form-string "webhook[url]=$url")

  for action in "${actions[@]}"; do
    curl_args+=(--form-string "webhook[subscribed_actions][]=$action")
  done

  curl_args+=("$FIZZY_BASE_URL/$account_slug/boards/$board_id/webhooks.json")

  local response
  response=$(curl "${curl_args[@]}")

  local http_code
  http_code=$(echo "$response" | tail -n1)
  response=$(echo "$response" | sed '$d')

  case "$http_code" in
    200|201|302) ;;
    401|403)
      die "Not authorized" $EXIT_FORBIDDEN "Only admins can create webhooks"
      ;;
    422)
      local error_msg
      error_msg=$(echo "$response" | jq -r '.errors // "Validation failed"' 2>/dev/null || echo "Validation failed")
      die "Validation error: $error_msg" $EXIT_API
      ;;
    *)
      die "API error: HTTP $http_code" $EXIT_API
      ;;
  esac

  # Try to parse response or construct one
  if ! echo "$response" | jq -e '.id' > /dev/null 2>&1; then
    response=$(jq -n --arg name "$name" --arg url "$url" \
      '{name: $name, url: $url, created: true}')
  fi

  local summary="Created webhook $name"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "list" "fizzy webhooks --board $board_id" "List webhooks")"
  )

  output "$response" "$summary" "$breadcrumbs" "_webhook_md"
}

_webhook_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local id name url
  id=$(echo "$data" | jq -r '.id // "pending"')
  name=$(echo "$data" | jq -r '.name // "unknown"')
  url=$(echo "$data" | jq -r '.url // "unknown"')

  local actions
  actions=$(echo "$data" | jq -r '.subscribed_actions // [] | join(", ")')
  [[ -z "$actions" ]] && actions="(none)"

  md_heading 2 "Webhook: $name"
  echo
  md_kv "ID" "$id" \
        "URL" "$url" \
        "Actions" "$actions"

  md_breadcrumbs "$breadcrumbs"
}

_webhook_create_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy webhook create",
      description: "Create a webhook",
      usage: "fizzy webhook create --board <board> --name <name> --url <url> [--actions ...]",
      options: [
        {flag: "--board, -b", description: "Board ID or name"},
        {flag: "--name, -n", description: "Webhook name"},
        {flag: "--url, -u", description: "Webhook URL"},
        {flag: "--actions, -a", description: "Event types to subscribe to"}
      ],
      available_actions: [
        "card_assigned", "card_closed", "card_postponed",
        "card_auto_postponed", "card_board_changed", "card_published",
        "card_reopened", "card_sent_back_to_triage", "card_triaged",
        "card_unassigned", "comment_created"
      ],
      examples: [
        "fizzy webhook create --board \"My Board\" --name \"Slack\" --url \"https://hooks.slack.com/...\" --actions card_published card_closed"
      ]
    }'
  else
    cat <<'EOF'
## fizzy webhook create

Create a webhook.

### Usage

    fizzy webhook create --board <board> --name <name> --url <url> [--actions ...]

### Options

    --board, -b     Board ID or name
    --name, -n      Webhook name
    --url, -u       Webhook URL
    --actions, -a   Event types to subscribe to

### Available Actions

    card_assigned            card_closed              card_postponed
    card_auto_postponed      card_board_changed       card_published
    card_reopened            card_sent_back_to_triage card_triaged
    card_unassigned          comment_created

### Examples

    fizzy webhook create --board "My Board" --name "Slack" \
      --url "https://hooks.slack.com/..." --actions card_published card_closed
EOF
  fi
}


# fizzy webhook show <id> --board <board>

_webhook_show() {
  local webhook_id=""
  local board_id=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --board|-b|--in)
        if [[ -z "${2:-}" ]]; then
          die "--board requires a board name or ID" $EXIT_USAGE
        fi
        board_id="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy webhook show --help"
        ;;
      *)
        if [[ -z "$webhook_id" ]]; then
          webhook_id="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _webhook_show_help
    return 0
  fi

  if [[ -z "$webhook_id" ]]; then
    die "Webhook ID required" $EXIT_USAGE "Usage: fizzy webhook show <id> --board <board>"
  fi

  # Resolve board
  if [[ -z "$board_id" ]]; then
    board_id=$(get_board_id 2>/dev/null || true)
  fi
  if [[ -z "$board_id" ]]; then
    die "Board required" $EXIT_USAGE "Use --board or set default board"
  fi

  local resolved_board
  if resolved_board=$(resolve_board_id "$board_id"); then
    board_id="$resolved_board"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy boards"
  fi

  local response
  response=$(api_get "/boards/$board_id/webhooks/$webhook_id")

  local webhook_name
  webhook_name=$(echo "$response" | jq -r '.name // "unknown"')

  local summary="Webhook: $webhook_name"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "list" "fizzy webhooks --board $board_id" "List webhooks")" \
    "$(breadcrumb "update" "fizzy webhook update $webhook_id --board $board_id" "Update")" \
    "$(breadcrumb "delete" "fizzy webhook delete $webhook_id --board $board_id" "Delete")"
  )

  output "$response" "$summary" "$breadcrumbs" "_webhook_md"
}

_webhook_show_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy webhook show",
      description: "Show webhook details",
      usage: "fizzy webhook show <id> --board <board>",
      options: [
        {flag: "--board, -b", description: "Board ID or name"}
      ],
      examples: [
        "fizzy webhook show abc123 --board \"My Board\""
      ]
    }'
  else
    cat <<'EOF'
## fizzy webhook show

Show webhook details.

### Usage

    fizzy webhook show <id> --board <board>

### Options

    --board, -b   Board ID or name

### Examples

    fizzy webhook show abc123 --board "My Board"
EOF
  fi
}


# fizzy webhook update <id> --board <board> [--name <name>] [--actions ...]

_webhook_update() {
  local webhook_id=""
  local board_id=""
  local name=""
  local actions=()
  local has_actions=false
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --board|-b|--in)
        if [[ -z "${2:-}" ]]; then
          die "--board requires a board name or ID" $EXIT_USAGE
        fi
        board_id="$2"
        shift 2
        ;;
      --name|-n)
        if [[ -z "${2:-}" ]]; then
          die "--name requires a value" $EXIT_USAGE
        fi
        name="$2"
        shift 2
        ;;
      --actions|-a)
        has_actions=true
        shift
        while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; do
          actions+=("$1")
          shift
        done
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy webhook update --help"
        ;;
      *)
        if [[ -z "$webhook_id" ]]; then
          webhook_id="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _webhook_update_help
    return 0
  fi

  if [[ -z "$webhook_id" ]]; then
    die "Webhook ID required" $EXIT_USAGE "Usage: fizzy webhook update <id> --board <board>"
  fi

  if [[ -z "$name" ]] && [[ "$has_actions" == "false" ]]; then
    die "Nothing to update" $EXIT_USAGE "Provide --name or --actions"
  fi

  # Resolve board
  if [[ -z "$board_id" ]]; then
    board_id=$(get_board_id 2>/dev/null || true)
  fi
  if [[ -z "$board_id" ]]; then
    die "Board required" $EXIT_USAGE "Use --board or set default board"
  fi

  local resolved_board
  if resolved_board=$(resolve_board_id "$board_id"); then
    board_id="$resolved_board"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy boards"
  fi

  local token
  token=$(ensure_auth)

  local account_slug
  account_slug=$(get_account_slug)

  # Build form data
  local curl_args=(
    -s -w '\n%{http_code}'
    -X PATCH
    -H "Authorization: Bearer $token"
    -H "User-Agent: $FIZZY_USER_AGENT"
    -H "Accept: application/json"
  )

  if [[ -n "$name" ]]; then
    curl_args+=(--form-string "webhook[name]=$name")
  fi

  if [[ "$has_actions" == "true" ]]; then
    for action in "${actions[@]}"; do
      curl_args+=(--form-string "webhook[subscribed_actions][]=$action")
    done
    # Include empty if no actions specified (clears all)
    if [[ ${#actions[@]} -eq 0 ]]; then
      curl_args+=(--form-string "webhook[subscribed_actions][]=")
    fi
  fi

  curl_args+=("$FIZZY_BASE_URL/$account_slug/boards/$board_id/webhooks/$webhook_id.json")

  local response
  response=$(curl "${curl_args[@]}")

  local http_code
  http_code=$(echo "$response" | tail -n1)

  case "$http_code" in
    200|204|302) ;;
    401|403)
      die "Not authorized" $EXIT_FORBIDDEN "Only admins can update webhooks"
      ;;
    404)
      die "Webhook not found" $EXIT_NOT_FOUND
      ;;
    422)
      die "Validation error" $EXIT_API "Check the provided values"
      ;;
    *)
      die "API error: HTTP $http_code" $EXIT_API
      ;;
  esac

  # Fetch updated webhook
  local updated
  updated=$(api_get "/boards/$board_id/webhooks/$webhook_id")

  local webhook_name
  webhook_name=$(echo "$updated" | jq -r '.name // "unknown"')

  local summary="Updated webhook $webhook_name"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy webhook show $webhook_id --board $board_id" "View")" \
    "$(breadcrumb "list" "fizzy webhooks --board $board_id" "List webhooks")"
  )

  output "$updated" "$summary" "$breadcrumbs" "_webhook_md"
}

_webhook_update_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy webhook update",
      description: "Update a webhook",
      usage: "fizzy webhook update <id> --board <board> [--name <name>] [--actions ...]",
      options: [
        {flag: "--board, -b", description: "Board ID or name"},
        {flag: "--name, -n", description: "New webhook name"},
        {flag: "--actions, -a", description: "New event types (replaces existing)"}
      ],
      notes: ["URL cannot be changed after creation"],
      examples: [
        "fizzy webhook update abc123 --board \"My Board\" --name \"New Name\"",
        "fizzy webhook update abc123 --board \"My Board\" --actions card_published"
      ]
    }'
  else
    cat <<'EOF'
## fizzy webhook update

Update a webhook.

### Usage

    fizzy webhook update <id> --board <board> [--name <name>] [--actions ...]

### Options

    --board, -b     Board ID or name
    --name, -n      New webhook name
    --actions, -a   New event types (replaces existing)

### Notes

URL cannot be changed after creation.

### Examples

    fizzy webhook update abc123 --board "My Board" --name "New Name"
    fizzy webhook update abc123 --board "My Board" --actions card_published
EOF
  fi
}


# fizzy webhook delete <id> --board <board>

_webhook_delete() {
  local webhook_id=""
  local board_id=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --board|-b|--in)
        if [[ -z "${2:-}" ]]; then
          die "--board requires a board name or ID" $EXIT_USAGE
        fi
        board_id="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy webhook delete --help"
        ;;
      *)
        if [[ -z "$webhook_id" ]]; then
          webhook_id="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _webhook_delete_help
    return 0
  fi

  if [[ -z "$webhook_id" ]]; then
    die "Webhook ID required" $EXIT_USAGE "Usage: fizzy webhook delete <id> --board <board>"
  fi

  # Resolve board
  if [[ -z "$board_id" ]]; then
    board_id=$(get_board_id 2>/dev/null || true)
  fi
  if [[ -z "$board_id" ]]; then
    die "Board required" $EXIT_USAGE "Use --board or set default board"
  fi

  local resolved_board
  if resolved_board=$(resolve_board_id "$board_id"); then
    board_id="$resolved_board"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy boards"
  fi

  # Fetch webhook name before delete
  local webhook_data
  webhook_data=$(api_get "/boards/$board_id/webhooks/$webhook_id" 2>/dev/null || echo '{}')
  local webhook_name
  webhook_name=$(echo "$webhook_data" | jq -r '.name // "unknown"')

  api_delete "/boards/$board_id/webhooks/$webhook_id" > /dev/null

  local result
  result=$(jq -n --arg id "$webhook_id" --arg name "$webhook_name" \
    '{id: $id, name: $name, deleted: true}')

  local summary="Deleted webhook $webhook_name"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "list" "fizzy webhooks --board $board_id" "List webhooks")"
  )

  output "$result" "$summary" "$breadcrumbs" "_webhook_deleted_md"
}

_webhook_deleted_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local name
  name=$(echo "$data" | jq -r '.name // "unknown"')

  md_heading 2 "Webhook Deleted"
  echo
  echo "Webhook **$name** has been deleted."

  md_breadcrumbs "$breadcrumbs"
}

_webhook_delete_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy webhook delete",
      description: "Delete a webhook",
      usage: "fizzy webhook delete <id> --board <board>",
      options: [
        {flag: "--board, -b", description: "Board ID or name"}
      ],
      examples: [
        "fizzy webhook delete abc123 --board \"My Board\""
      ]
    }'
  else
    cat <<'EOF'
## fizzy webhook delete

Delete a webhook.

### Usage

    fizzy webhook delete <id> --board <board>

### Options

    --board, -b   Board ID or name

### Examples

    fizzy webhook delete abc123 --board "My Board"
EOF
  fi
}
