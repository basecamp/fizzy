#!/usr/bin/env bash
# boards.sh - Board and column query commands


# fizzy boards [options]
# List boards in the account

cmd_boards() {
  local show_help=false
  local page=""
  local fetch_all=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all|-a)
        fetch_all=true
        shift
        ;;
      --page|-p)
        if [[ -z "${2:-}" ]]; then
          die "--page requires a value" $EXIT_USAGE
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -lt 1 ]]; then
          die "--page must be a positive integer" $EXIT_USAGE
        fi
        page="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      *)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy boards --help"
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _boards_help
    return 0
  fi

  local response
  if [[ "$fetch_all" == "true" ]]; then
    response=$(api_get_all "/boards")
  else
    local path="/boards"
    if [[ -n "$page" ]]; then
      path="$path?page=$page"
    fi
    response=$(api_get "$path")
  fi

  local count
  count=$(echo "$response" | jq 'length')

  local summary="$count boards"
  [[ -n "$page" ]] && summary="$count boards (page $page)"
  [[ "$fetch_all" == "true" ]] && summary="$count boards (all)"

  local next_page=$((${page:-1} + 1))
  local breadcrumbs
  if [[ "$fetch_all" == "true" ]]; then
    breadcrumbs=$(breadcrumbs \
      "$(breadcrumb "show" "fizzy show board <id>" "View board details")" \
      "$(breadcrumb "cards" "fizzy cards --board <id>" "List cards on board")" \
      "$(breadcrumb "columns" "fizzy columns --board <id>" "List board columns")"
    )
  else
    breadcrumbs=$(breadcrumbs \
      "$(breadcrumb "show" "fizzy show board <id>" "View board details")" \
      "$(breadcrumb "cards" "fizzy cards --board <id>" "List cards on board")" \
      "$(breadcrumb "columns" "fizzy columns --board <id>" "List board columns")" \
      "$(breadcrumb "next" "fizzy boards --page $next_page" "Next page")"
    )
  fi

  output "$response" "$summary" "$breadcrumbs" "_boards_md"
}

_boards_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  md_heading 2 "Boards ($summary)"

  local count
  count=$(echo "$data" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No boards found."
    echo
  else
    echo "| ID | Name | Access | Created |"
    echo "|----|------|--------|---------|"
    echo "$data" | jq -r '.[] | "| \(.id) | \(.name) | \(if .all_access then "All" else "Selective" end) | \(.created_at | split("T")[0]) |"'
    echo
  fi

  md_breadcrumbs "$breadcrumbs"
}

_boards_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy boards",
      description: "List boards in the account",
      options: [
        {flag: "--all, -a", description: "Fetch all pages"},
        {flag: "--page, -p", description: "Page number for pagination"}
      ],
      examples: [
        "fizzy boards",
        "fizzy boards --all",
        "fizzy boards --page 2"
      ]
    }'
  else
    cat <<'EOF'
## fizzy boards

List boards in the account.

### Usage

    fizzy boards [options]

### Options

    --all, -a     Fetch all pages
    --page, -p    Page number for pagination
    --help, -h    Show this help

### Examples

    fizzy boards              List boards (first page)
    fizzy boards --all        Fetch all boards
    fizzy boards --page 2     Get second page
EOF
  fi
}


# fizzy board <subcommand>
# Manage boards (create, update, delete, show)

cmd_board() {
  case "${1:-}" in
    create)
      shift
      _board_create "$@"
      ;;
    update)
      shift
      _board_update "$@"
      ;;
    delete)
      shift
      _board_delete "$@"
      ;;
    show)
      shift
      _board_show "$@"
      ;;
    publish)
      shift
      _board_publish "$@"
      ;;
    unpublish)
      shift
      _board_unpublish "$@"
      ;;
    entropy)
      shift
      _board_entropy "$@"
      ;;
    --help|-h|"")
      _board_help
      ;;
    *)
      die "Unknown subcommand: board ${1:-}" $EXIT_USAGE \
        "Available: fizzy board create|update|delete|show|publish|unpublish|entropy"
      ;;
  esac
}

_board_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy board",
      description: "Manage boards",
      subcommands: [
        {name: "create", description: "Create a new board"},
        {name: "update", description: "Update a board"},
        {name: "delete", description: "Delete a board"},
        {name: "show", description: "Show board details"},
        {name: "publish", description: "Publish board publicly"},
        {name: "unpublish", description: "Unpublish board"},
        {name: "entropy", description: "Set auto-postpone period"}
      ],
      examples: [
        "fizzy board create \"New Board\"",
        "fizzy board update abc123 --name \"Renamed\"",
        "fizzy board delete abc123",
        "fizzy board show abc123",
        "fizzy board publish abc123",
        "fizzy board entropy abc123 --period 14"
      ]
    }'
  else
    cat <<'EOF'
## fizzy board

Manage boards.

### Subcommands

    create       Create a new board
    update       Update a board
    delete       Delete a board
    show         Show board details
    publish      Publish board publicly (shareable link)
    unpublish    Unpublish board
    entropy      Set auto-postpone period

### Examples

    fizzy board create "New Board"
    fizzy board update abc123 --name "Renamed"
    fizzy board delete abc123
    fizzy board show abc123
    fizzy board publish abc123
    fizzy board entropy abc123 --period 14
EOF
  fi
}

_board_create() {
  local name=""
  local all_access=""
  local all_access_flag=false
  local selective_flag=false
  local auto_postpone=""
  local public_description=""
  local public_description_file=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        if [[ -z "${2:-}" ]]; then
          die "--name requires a value" $EXIT_USAGE
        fi
        name="$2"
        shift 2
        ;;
      --all-access)
        all_access="true"
        all_access_flag=true
        shift
        ;;
      --selective)
        all_access="false"
        selective_flag=true
        shift
        ;;
      --auto-postpone|--auto-postpone-period)
        if [[ -z "${2:-}" ]]; then
          die "--auto-postpone requires a value" $EXIT_USAGE
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
          die "--auto-postpone must be a non-negative integer" $EXIT_USAGE
        fi
        auto_postpone="$2"
        shift 2
        ;;
      --public-description)
        if [[ -z "${2:-}" ]]; then
          die "--public-description requires text" $EXIT_USAGE
        fi
        public_description="$2"
        shift 2
        ;;
      --public-description-file)
        if [[ -z "${2:-}" ]]; then
          die "--public-description-file requires a file path" $EXIT_USAGE
        fi
        public_description_file="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy board create --help"
        ;;
      *)
        if [[ -z "$name" ]]; then
          name="$1"
          shift
        else
          die "Unexpected argument: $1" $EXIT_USAGE
        fi
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _board_create_help
    return 0
  fi

  if [[ -n "$public_description_file" ]]; then
    if [[ ! -f "$public_description_file" ]]; then
      die "File not found: $public_description_file" $EXIT_USAGE
    fi
    public_description=$(cat "$public_description_file")
  fi

  if [[ -z "$name" ]]; then
    die "Board name required" $EXIT_USAGE "Usage: fizzy board create \"name\""
  fi

  if [[ "$all_access_flag" == "true" && "$selective_flag" == "true" ]]; then
    die "Cannot use --all-access and --selective together" $EXIT_USAGE
  fi

  local board_payload
  board_payload=$(jq -n \
    --arg name "$name" \
    --arg auto_postpone "$auto_postpone" \
    --arg public_description "$public_description" \
    --arg all_access "$all_access" \
    '(
      (if $name != "" then {name: $name} else {} end) +
      (if $auto_postpone != "" then {auto_postpone_period: ($auto_postpone | tonumber)} else {} end) +
      (if $public_description != "" then {public_description: $public_description} else {} end) +
      (if $all_access != "" then {all_access: ($all_access == "true")} else {} end)
    )')

  local body
  body=$(jq -n --argjson board "$board_payload" '{board: $board}')

  local response
  response=$(api_post "/boards" "$body")

  local summary="Created board \"$name\""

  local board_id
  board_id=$(echo "$response" | jq -r '.id')

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy show board $board_id" "View board details")" \
    "$(breadcrumb "cards" "fizzy cards --board $board_id" "List cards")" \
    "$(breadcrumb "columns" "fizzy columns --board $board_id" "List columns")"
  )

  output "$response" "$summary" "$breadcrumbs" "_show_board_md"
}

_board_create_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy board create",
      description: "Create a new board",
      usage: "fizzy board create \"name\" [options]",
      options: [
        {flag: "--name", description: "Board name (positional allowed)"},
        {flag: "--all-access", description: "All users can access (default)"},
        {flag: "--selective", description: "Restrict board access to selected users"},
        {flag: "--auto-postpone", description: "Days before cards auto-postpone"},
        {flag: "--public-description", description: "Public description (HTML)"},
        {flag: "--public-description-file", description: "Read public description from file"}
      ],
      examples: [
        "fizzy board create \"New Board\"",
        "fizzy board create \"Client\" --selective",
        "fizzy board create \"Launch\" --auto-postpone 14"
      ]
    }'
  else
    cat <<'EOF'
## fizzy board create

Create a new board.

### Usage

    fizzy board create "name" [options]

### Options

    --name                     Board name (positional allowed)
    --all-access               All users can access (default)
    --selective                Restrict access to selected users
    --auto-postpone            Days before cards auto-postpone
    --public-description       Public description (HTML)
    --public-description-file  Read public description from file
    --help, -h                 Show this help

### Examples

    fizzy board create "New Board"
    fizzy board create "Client" --selective
    fizzy board create "Launch" --auto-postpone 14
EOF
  fi
}

_board_update() {
  local board_id=""
  local name=""
  local all_access=""
  local all_access_flag=false
  local selective_flag=false
  local auto_postpone=""
  local public_description=""
  local public_description_file=""
  local user_inputs=()
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        if [[ -z "${2:-}" ]]; then
          die "--name requires a value" $EXIT_USAGE
        fi
        name="$2"
        shift 2
        ;;
      --all-access)
        all_access="true"
        all_access_flag=true
        shift
        ;;
      --selective)
        all_access="false"
        selective_flag=true
        shift
        ;;
      --auto-postpone|--auto-postpone-period)
        if [[ -z "${2:-}" ]]; then
          die "--auto-postpone requires a value" $EXIT_USAGE
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
          die "--auto-postpone must be a non-negative integer" $EXIT_USAGE
        fi
        auto_postpone="$2"
        shift 2
        ;;
      --public-description)
        if [[ -z "${2:-}" ]]; then
          die "--public-description requires text" $EXIT_USAGE
        fi
        public_description="$2"
        shift 2
        ;;
      --public-description-file)
        if [[ -z "${2:-}" ]]; then
          die "--public-description-file requires a file path" $EXIT_USAGE
        fi
        public_description_file="$2"
        shift 2
        ;;
      --user)
        if [[ -z "${2:-}" ]]; then
          die "--user requires a name, email, or ID" $EXIT_USAGE
        fi
        user_inputs+=("$2")
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy board update --help"
        ;;
      *)
        if [[ -z "$board_id" ]]; then
          board_id="$1"
          shift
        else
          die "Unexpected argument: $1" $EXIT_USAGE
        fi
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _board_update_help
    return 0
  fi

  if [[ -z "$board_id" ]]; then
    die "Board ID required" $EXIT_USAGE "Usage: fizzy board update <id> [options]"
  fi

  if [[ -n "$public_description_file" ]]; then
    if [[ ! -f "$public_description_file" ]]; then
      die "File not found: $public_description_file" $EXIT_USAGE
    fi
    public_description=$(cat "$public_description_file")
  fi

  if [[ "$all_access_flag" == "true" && "$selective_flag" == "true" ]]; then
    die "Cannot use --all-access and --selective together" $EXIT_USAGE
  fi

  if [[ ${#user_inputs[@]} -gt 0 ]]; then
    if [[ "$all_access" == "true" ]]; then
      die "--user cannot be combined with --all-access" $EXIT_USAGE
    fi
    if [[ -z "$all_access" ]]; then
      all_access="false"
    fi
  fi

  # Resolve board ID (accepts name)
  local resolved_board
  if resolved_board=$(resolve_board_id "$board_id"); then
    board_id="$resolved_board"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy boards"
  fi

  # Resolve user IDs
  local user_ids=()
  local input
  for input in "${user_inputs[@]}"; do
    local resolved_user
    if resolved_user=$(resolve_user_id "$input"); then
      user_ids+=("$resolved_user")
    else
      die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy people"
    fi
  done

  local board_payload
  board_payload=$(jq -n \
    --arg name "$name" \
    --arg auto_postpone "$auto_postpone" \
    --arg public_description "$public_description" \
    --arg all_access "$all_access" \
    '(
      (if $name != "" then {name: $name} else {} end) +
      (if $auto_postpone != "" then {auto_postpone_period: ($auto_postpone | tonumber)} else {} end) +
      (if $public_description != "" then {public_description: $public_description} else {} end) +
      (if $all_access != "" then {all_access: ($all_access == "true")} else {} end)
    )')

  local user_ids_json="null"
  if [[ ${#user_ids[@]} -gt 0 ]]; then
    user_ids_json=$(printf '%s\n' "${user_ids[@]}" | jq -R . | jq -s '.')
  fi

  if [[ "$board_payload" == "{}" && "$user_ids_json" == "null" ]]; then
    die "Nothing to update. Specify changes" $EXIT_USAGE
  fi

  local body
  body=$(jq -n \
    --argjson board "$board_payload" \
    --argjson user_ids "$user_ids_json" \
    '(
      (if ($board | length) > 0 then {board: $board} else {} end) +
      (if $user_ids != null then {user_ids: $user_ids} else {} end)
    )')

  # PATCH returns 204 No Content
  api_patch "/boards/$board_id" "$body" > /dev/null
  local response
  response=$(api_get "/boards/$board_id")

  local summary="Board updated"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy show board $board_id" "View board details")" \
    "$(breadcrumb "cards" "fizzy cards --board $board_id" "List cards")"
  )

  output "$response" "$summary" "$breadcrumbs" "_show_board_md"
}

_board_update_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy board update",
      description: "Update a board",
      usage: "fizzy board update <id> [options]",
      options: [
        {flag: "--name", description: "New board name"},
        {flag: "--all-access", description: "All users can access"},
        {flag: "--selective", description: "Restrict access to selected users"},
        {flag: "--auto-postpone", description: "Days before cards auto-postpone"},
        {flag: "--public-description", description: "Public description (HTML)"},
        {flag: "--public-description-file", description: "Read public description from file"},
        {flag: "--user", description: "User name/email/ID (repeatable)"}
      ],
      examples: [
        "fizzy board update abc123 --name \"Renamed\"",
        "fizzy board update abc123 --auto-postpone 14",
        "fizzy board update abc123 --selective --user \"Jane Doe\""
      ]
    }'
  else
    cat <<'EOF'
## fizzy board update

Update a board.

### Usage

    fizzy board update <id> [options]

### Options

    --name                     New board name
    --all-access               All users can access
    --selective                Restrict access to selected users
    --auto-postpone            Days before cards auto-postpone
    --public-description       Public description (HTML)
    --public-description-file  Read public description from file
    --user                     User name/email/ID (repeatable)
    --help, -h                 Show this help

### Examples

    fizzy board update abc123 --name "Renamed"
    fizzy board update abc123 --auto-postpone 14
    fizzy board update abc123 --selective --user "Jane Doe"
EOF
  fi
}

_board_delete() {
  local board_id=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy board delete --help"
        ;;
      *)
        if [[ -z "$board_id" ]]; then
          board_id="$1"
          shift
        else
          die "Unexpected argument: $1" $EXIT_USAGE
        fi
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _board_delete_help
    return 0
  fi

  if [[ -z "$board_id" ]]; then
    die "Board ID required" $EXIT_USAGE "Usage: fizzy board delete <id>"
  fi

  local resolved_board
  if resolved_board=$(resolve_board_id "$board_id"); then
    board_id="$resolved_board"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy boards"
  fi

  # DELETE returns 204 No Content
  api_delete "/boards/$board_id" > /dev/null

  local response
  response=$(jq -n --arg id "$board_id" '{id: $id, deleted: true}')

  local summary="Board deleted"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "boards" "fizzy boards" "List boards")" \
    "$(breadcrumb "board" "fizzy board create \"name\"" "Create board")"
  )

  output "$response" "$summary" "$breadcrumbs" "_board_deleted_md"
}

_board_deleted_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local board_id
  board_id=$(echo "$data" | jq -r '.id')

  md_heading 2 "Board Deleted"
  echo
  md_kv "ID" "$board_id" \
        "Status" "Deleted"

  md_breadcrumbs "$breadcrumbs"
}

_board_delete_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy board delete",
      description: "Delete a board",
      usage: "fizzy board delete <id>",
      warning: "This action cannot be undone",
      examples: ["fizzy board delete abc123"]
    }'
  else
    cat <<'EOF'
## fizzy board delete

Delete a board.

**Warning:** This action cannot be undone.

### Usage

    fizzy board delete <id>

### Examples

    fizzy board delete abc123
EOF
  fi
}

_board_show() {
  local board_id="${1:-}"

  if [[ -z "$board_id" ]]; then
    die "Board ID required" $EXIT_USAGE "Usage: fizzy board show <id>"
  fi

  local resolved_board
  if resolved_board=$(resolve_board_id "$board_id"); then
    board_id="$resolved_board"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy boards"
  fi

  show_board "$board_id"
}


# fizzy board publish <board>
# Publish board publicly (creates shareable link)

_board_publish() {
  local board_ref=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy board publish --help"
        ;;
      *)
        if [[ -z "$board_ref" ]]; then
          board_ref="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _board_publish_help
    return 0
  fi

  if [[ -z "$board_ref" ]]; then
    die "Board name or ID required" $EXIT_USAGE "Usage: fizzy board publish <board>"
  fi

  local board_id
  board_id=$(resolve_board_id "$board_ref") || exit $?

  local publish_response
  publish_response=$(api_post "/boards/$board_id/publication")

  local board_response
  board_response=$(api_get "/boards/$board_id")

  local board_name published_url
  board_name=$(echo "$board_response" | jq -r '.name')
  published_url=$(echo "$publish_response" | jq -r '.url')

  # Merge the published_url into the board response for output
  local response
  response=$(echo "$board_response" | jq --arg url "$published_url" '. + {published_url: $url}')

  local summary="Board \"$board_name\" published"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "unpublish" "fizzy board unpublish $board_id" "Unpublish board")" \
    "$(breadcrumb "show" "fizzy board show $board_id" "View board")"
  )

  output "$response" "$summary" "$breadcrumbs" "_board_publish_md"
}

_board_publish_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local name published_url
  name=$(echo "$data" | jq -r '.name')
  published_url=$(echo "$data" | jq -r '.published_url // "pending"')

  md_heading 2 "Board Published"
  echo
  md_kv "Board" "$name" \
        "Public URL" "$published_url"

  md_breadcrumbs "$breadcrumbs"
}

_board_publish_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy board publish",
      description: "Publish board publicly",
      usage: "fizzy board publish <board>",
      examples: ["fizzy board publish \"My Board\""]
    }'
  else
    cat <<'EOF'
## fizzy board publish

Publish board publicly, creating a shareable link.

### Usage

    fizzy board publish <board>

### Examples

    fizzy board publish "My Board"
    fizzy board publish abc123
EOF
  fi
}


# fizzy board unpublish <board>
# Unpublish board (remove public access)

_board_unpublish() {
  local board_ref=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy board unpublish --help"
        ;;
      *)
        if [[ -z "$board_ref" ]]; then
          board_ref="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _board_unpublish_help
    return 0
  fi

  if [[ -z "$board_ref" ]]; then
    die "Board name or ID required" $EXIT_USAGE "Usage: fizzy board unpublish <board>"
  fi

  local board_id
  board_id=$(resolve_board_id "$board_ref") || exit $?

  api_delete "/boards/$board_id/publication" > /dev/null

  local response
  response=$(api_get "/boards/$board_id")

  local board_name
  board_name=$(echo "$response" | jq -r '.name')

  local summary="Board \"$board_name\" unpublished"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "publish" "fizzy board publish $board_id" "Publish board")" \
    "$(breadcrumb "show" "fizzy board show $board_id" "View board")"
  )

  output "$response" "$summary" "$breadcrumbs" "_board_unpublish_md"
}

_board_unpublish_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local name
  name=$(echo "$data" | jq -r '.name')

  md_heading 2 "Board Unpublished"
  echo
  md_kv "Board" "$name" \
        "Status" "Private"

  md_breadcrumbs "$breadcrumbs"
}

_board_unpublish_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy board unpublish",
      description: "Unpublish board",
      usage: "fizzy board unpublish <board>",
      examples: ["fizzy board unpublish \"My Board\""]
    }'
  else
    cat <<'EOF'
## fizzy board unpublish

Unpublish board, removing public access.

### Usage

    fizzy board unpublish <board>

### Examples

    fizzy board unpublish "My Board"
    fizzy board unpublish abc123
EOF
  fi
}


# fizzy board entropy <board> --period <days>
# Set auto-postpone period for board

_board_entropy() {
  local board_ref=""
  local period=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --period|-p)
        if [[ -z "${2:-}" ]]; then
          die "--period requires a value (days)" $EXIT_USAGE
        fi
        period="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy board entropy --help"
        ;;
      *)
        if [[ -z "$board_ref" ]]; then
          board_ref="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _board_entropy_help
    return 0
  fi

  if [[ -z "$board_ref" ]]; then
    die "Board name or ID required" $EXIT_USAGE "Usage: fizzy board entropy <board> --period <days>"
  fi

  if [[ -z "$period" ]]; then
    die "--period <days> required" $EXIT_USAGE "Usage: fizzy board entropy <board> --period <days>"
  fi

  local board_id
  board_id=$(resolve_board_id "$board_ref") || exit $?

  local body
  body=$(jq -n --argjson period "$period" '{board: {auto_postpone_period: $period}}')
  api_patch "/boards/$board_id/entropy" "$body" > /dev/null

  local response
  response=$(api_get "/boards/$board_id")

  local board_name
  board_name=$(echo "$response" | jq -r '.name')

  local summary="Board \"$board_name\" entropy set to $period days"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy board show $board_id" "View board")" \
    "$(breadcrumb "cards" "fizzy cards --board $board_id" "List cards")"
  )

  output "$response" "$summary" "$breadcrumbs" "_board_entropy_md"
}

_board_entropy_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local name period
  name=$(echo "$data" | jq -r '.name')
  period=$(echo "$data" | jq -r '.auto_postpone_period // "default"')

  md_heading 2 "Board Entropy Updated"
  echo
  md_kv "Board" "$name" \
        "Auto-postpone period" "$period days"

  md_breadcrumbs "$breadcrumbs"
}

_board_entropy_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy board entropy",
      description: "Set auto-postpone period for board",
      usage: "fizzy board entropy <board> --period <days>",
      options: [
        {flag: "--period, -p", description: "Number of days before cards auto-postpone"}
      ],
      examples: [
        "fizzy board entropy \"My Board\" --period 14",
        "fizzy board entropy abc123 --period 7"
      ]
    }'
  else
    cat <<'EOF'
## fizzy board entropy

Set auto-postpone period for board. Cards without activity will
automatically move to "Not Now" after this many days.

### Usage

    fizzy board entropy <board> --period <days>

### Options

    --period, -p    Number of days before cards auto-postpone

### Examples

    fizzy board entropy "My Board" --period 14
    fizzy board entropy abc123 --period 7
EOF
  fi
}


# fizzy columns [options]
# List columns on a board

cmd_columns() {
  local board_id=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --board|-b|--in)
        if [[ -z "${2:-}" ]]; then
          die "--board requires a value" $EXIT_USAGE
        fi
        board_id="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      *)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy columns --help"
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _columns_help
    return 0
  fi

  # Use provided board_id or fall back to config
  if [[ -z "$board_id" ]]; then
    board_id=$(get_board_id)
  fi

  if [[ -z "$board_id" ]]; then
    die "No board specified" $EXIT_USAGE \
      "Use: fizzy columns --board <name>"
  fi

  # Resolve board name to ID if needed
  local resolved_board
  if resolved_board=$(resolve_board_id "$board_id"); then
    board_id="$resolved_board"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy boards"
  fi

  local response
  response=$(api_get "/boards/$board_id/columns")

  local count
  count=$(echo "$response" | jq 'length')

  local summary="$count columns"
  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "triage" "fizzy triage <card> --to <column_id>" "Move card to column")" \
    "$(breadcrumb "cards" "fizzy cards --board $board_id" "List cards on board")"
  )

  output "$response" "$summary" "$breadcrumbs" "_columns_md"
}

_columns_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  md_heading 2 "Columns ($summary)"

  local count
  count=$(echo "$data" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No columns found."
    echo
  else
    echo "| ID | Name | Color |"
    echo "|----|------|-------|"
    echo "$data" | jq -r '.[] | "| \(.id) | \(.name) | \(.color // "default") |"'
    echo
  fi

  md_breadcrumbs "$breadcrumbs"
}

_columns_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy columns",
      description: "List columns on a board",
      options: [
        {flag: "--board, -b, --in", description: "Board name or ID (required unless set in config)"}
      ],
      examples: [
        "fizzy columns --board \"My Board\"",
        "fizzy columns -b abc123 --json"
      ]
    }'
  else
    cat <<'EOF'
## fizzy columns

List columns on a board.

### Usage

    fizzy columns [options]

### Options

    --board, -b, --in   Board name or ID (required unless set in config)
    --help, -h    Show this help

### Examples

    fizzy columns --board "My Board"  List columns on board
    fizzy columns                     List columns on default board
EOF
  fi
}


# fizzy column <subcommand>
# Manage columns (create, update, delete, show)

cmd_column() {
  case "${1:-}" in
    create)
      shift
      _column_create "$@"
      ;;
    update)
      shift
      _column_update "$@"
      ;;
    delete)
      shift
      _column_delete "$@"
      ;;
    show)
      shift
      _column_show "$@"
      ;;
    left)
      shift
      _column_left "$@"
      ;;
    right)
      shift
      _column_right "$@"
      ;;
    --help|-h|"")
      _column_help
      ;;
    *)
      die "Unknown subcommand: column ${1:-}" $EXIT_USAGE \
        "Available: fizzy column create|update|delete|show|left|right"
      ;;
  esac
}

_column_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy column",
      description: "Manage columns on a board",
      subcommands: [
        {name: "create", description: "Create a column"},
        {name: "update", description: "Update a column"},
        {name: "delete", description: "Delete a column"},
        {name: "show", description: "Show column details"},
        {name: "left", description: "Move column left"},
        {name: "right", description: "Move column right"}
      ],
      examples: [
        "fizzy column create \"In Progress\" --board \"My Board\"",
        "fizzy column update abc123 --board \"My Board\" --name \"Done\"",
        "fizzy column delete abc123 --board \"My Board\"",
        "fizzy column show abc123 --board \"My Board\"",
        "fizzy column left abc123 --board \"My Board\"",
        "fizzy column right abc123 --board \"My Board\""
      ]
    }'
  else
    cat <<'EOF'
## fizzy column

Manage columns on a board.

### Subcommands

    create   Create a column
    update   Update a column
    delete   Delete a column
    show     Show column details
    left     Move column left (decrease position)
    right    Move column right (increase position)

### Examples

    fizzy column create "In Progress" --board "My Board"
    fizzy column update abc123 --board "My Board" --name "Done"
    fizzy column delete abc123 --board "My Board"
    fizzy column show abc123 --board "My Board"
    fizzy column left "In Progress" --board "My Board"
    fizzy column right "In Progress" --board "My Board"
EOF
  fi
}

_column_resolve_board() {
  local board_input="$1"

  if [[ -z "$board_input" ]]; then
    board_input=$(get_board_id 2>/dev/null || true)
  fi

  if [[ -z "$board_input" ]]; then
    die "No board specified" $EXIT_USAGE "Use: fizzy column <subcommand> --board <name>"
  fi

  local resolved_board
  if resolved_board=$(resolve_board_id "$board_input"); then
    echo "$resolved_board"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy boards"
  fi
}

_column_create() {
  local name=""
  local color=""
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
      --name)
        if [[ -z "${2:-}" ]]; then
          die "--name requires a value" $EXIT_USAGE
        fi
        name="$2"
        shift 2
        ;;
      --color)
        if [[ -z "${2:-}" ]]; then
          die "--color requires a value" $EXIT_USAGE
        fi
        color="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy column create --help"
        ;;
      *)
        if [[ -z "$name" ]]; then
          name="$1"
          shift
        else
          die "Unexpected argument: $1" $EXIT_USAGE
        fi
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _column_create_help
    return 0
  fi

  if [[ -z "$name" ]]; then
    die "Column name required" $EXIT_USAGE "Usage: fizzy column create \"name\" --board <board>"
  fi

  board_id=$(_column_resolve_board "$board_id")

  local column_payload
  column_payload=$(jq -n \
    --arg name "$name" \
    --arg color "$color" \
    '(
      (if $name != "" then {name: $name} else {} end) +
      (if $color != "" then {color: $color} else {} end)
    )')

  local body
  body=$(jq -n --argjson column "$column_payload" '{column: $column}')

  local response
  response=$(api_post "/boards/$board_id/columns" "$body")

  local summary="Created column \"$name\""

  local column_id
  column_id=$(echo "$response" | jq -r '.id')

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "columns" "fizzy columns --board $board_id" "List columns")" \
    "$(breadcrumb "show" "fizzy column show $column_id --board $board_id" "View column")"
  )

  output "$response" "$summary" "$breadcrumbs" "_column_md"
}

_column_create_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy column create",
      description: "Create a column on a board",
      usage: "fizzy column create \"name\" --board <board> [options]",
      options: [
        {flag: "--board, -b, --in", description: "Board name or ID"},
        {flag: "--name", description: "Column name (positional allowed)"},
        {flag: "--color", description: "Column color CSS variable"}
      ],
      examples: [
        "fizzy column create \"In Progress\" --board \"My Board\"",
        "fizzy column create \"Done\" --board abc123 --color \"var(--color-card-4)\""
      ]
    }'
  else
    cat <<'EOF'
## fizzy column create

Create a column on a board.

### Usage

    fizzy column create "name" --board <board> [options]

### Options

    --board, -b, --in   Board name or ID
    --name              Column name (positional allowed)
    --color             Column color CSS variable
    --help, -h          Show this help

### Examples

    fizzy column create "In Progress" --board "My Board"
    fizzy column create "Done" --board abc123 --color "var(--color-card-4)"
EOF
  fi
}

_column_update() {
  local column_id=""
  local board_id=""
  local name=""
  local color=""
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
      --name)
        if [[ -z "${2:-}" ]]; then
          die "--name requires a value" $EXIT_USAGE
        fi
        name="$2"
        shift 2
        ;;
      --color)
        if [[ -z "${2:-}" ]]; then
          die "--color requires a value" $EXIT_USAGE
        fi
        color="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy column update --help"
        ;;
      *)
        if [[ -z "$column_id" ]]; then
          column_id="$1"
          shift
        else
          die "Unexpected argument: $1" $EXIT_USAGE
        fi
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _column_update_help
    return 0
  fi

  if [[ -z "$column_id" ]]; then
    die "Column ID required" $EXIT_USAGE "Usage: fizzy column update <id> --board <board> [options]"
  fi

  board_id=$(_column_resolve_board "$board_id")

  if [[ -z "$name" && -z "$color" ]]; then
    die "Nothing to update. Specify --name or --color" $EXIT_USAGE
  fi

  local resolved_column
  if resolved_column=$(resolve_column_id "$column_id" "$board_id"); then
    column_id="$resolved_column"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy columns --board $board_id"
  fi

  local column_payload
  column_payload=$(jq -n \
    --arg name "$name" \
    --arg color "$color" \
    '(
      (if $name != "" then {name: $name} else {} end) +
      (if $color != "" then {color: $color} else {} end)
    )')

  local body
  body=$(jq -n --argjson column "$column_payload" '{column: $column}')

  # PATCH returns 204 No Content
  api_patch "/boards/$board_id/columns/$column_id" "$body" > /dev/null
  local response
  response=$(api_get "/boards/$board_id/columns/$column_id")

  local summary="Column updated"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "columns" "fizzy columns --board $board_id" "List columns")" \
    "$(breadcrumb "show" "fizzy column show $column_id --board $board_id" "View column")"
  )

  output "$response" "$summary" "$breadcrumbs" "_column_md"
}

_column_update_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy column update",
      description: "Update a column",
      usage: "fizzy column update <id> --board <board> [options]",
      options: [
        {flag: "--board, -b, --in", description: "Board name or ID"},
        {flag: "--name", description: "New column name"},
        {flag: "--color", description: "New column color"}
      ],
      examples: [
        "fizzy column update abc123 --board \"My Board\" --name \"Done\"",
        "fizzy column update abc123 --board \"My Board\" --color \"var(--color-card-4)\""
      ]
    }'
  else
    cat <<'EOF'
## fizzy column update

Update a column.

### Usage

    fizzy column update <id> --board <board> [options]

### Options

    --board, -b, --in   Board name or ID
    --name              New column name
    --color             New column color
    --help, -h          Show this help

### Examples

    fizzy column update abc123 --board "My Board" --name "Done"
    fizzy column update abc123 --board "My Board" --color "var(--color-card-4)"
EOF
  fi
}

_column_delete() {
  local column_id=""
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
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy column delete --help"
        ;;
      *)
        if [[ -z "$column_id" ]]; then
          column_id="$1"
          shift
        else
          die "Unexpected argument: $1" $EXIT_USAGE
        fi
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _column_delete_help
    return 0
  fi

  if [[ -z "$column_id" ]]; then
    die "Column ID required" $EXIT_USAGE "Usage: fizzy column delete <id> --board <board>"
  fi

  board_id=$(_column_resolve_board "$board_id")

  local resolved_column
  if resolved_column=$(resolve_column_id "$column_id" "$board_id"); then
    column_id="$resolved_column"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy columns --board $board_id"
  fi

  # DELETE returns 204 No Content
  api_delete "/boards/$board_id/columns/$column_id" > /dev/null

  local response
  response=$(jq -n --arg id "$column_id" '{id: $id, deleted: true}')

  local summary="Column deleted"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "columns" "fizzy columns --board $board_id" "List columns")" \
    "$(breadcrumb "column" "fizzy column create \"name\" --board $board_id" "Create column")"
  )

  output "$response" "$summary" "$breadcrumbs" "_column_deleted_md"
}

_column_deleted_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local column_id
  column_id=$(echo "$data" | jq -r '.id')

  md_heading 2 "Column Deleted"
  echo
  md_kv "ID" "$column_id" \
        "Status" "Deleted"

  md_breadcrumbs "$breadcrumbs"
}

_column_delete_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy column delete",
      description: "Delete a column",
      usage: "fizzy column delete <id> --board <board>",
      examples: ["fizzy column delete abc123 --board \"My Board\""]
    }'
  else
    cat <<'EOF'
## fizzy column delete

Delete a column.

### Usage

    fizzy column delete <id> --board <board>

### Examples

    fizzy column delete abc123 --board "My Board"
EOF
  fi
}

_column_show() {
  local column_id=""
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
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy column show --help"
        ;;
      *)
        if [[ -z "$column_id" ]]; then
          column_id="$1"
          shift
        else
          die "Unexpected argument: $1" $EXIT_USAGE
        fi
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _column_show_help
    return 0
  fi

  if [[ -z "$column_id" ]]; then
    die "Column ID required" $EXIT_USAGE "Usage: fizzy column show <id> --board <board>"
  fi

  board_id=$(_column_resolve_board "$board_id")

  local resolved_column
  if resolved_column=$(resolve_column_id "$column_id" "$board_id"); then
    column_id="$resolved_column"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy columns --board $board_id"
  fi

  local response
  response=$(api_get "/boards/$board_id/columns/$column_id")

  local summary="Column on board"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "columns" "fizzy columns --board $board_id" "List columns")" \
    "$(breadcrumb "update" "fizzy column update $column_id --board $board_id" "Update column")" \
    "$(breadcrumb "delete" "fizzy column delete $column_id --board $board_id" "Delete column")"
  )

  output "$response" "$summary" "$breadcrumbs" "_column_md"
}

_column_show_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy column show",
      description: "Show column details",
      usage: "fizzy column show <id> --board <board>",
      examples: ["fizzy column show abc123 --board \"My Board\""]
    }'
  else
    cat <<'EOF'
## fizzy column show

Show column details.

### Usage

    fizzy column show <id> --board <board>

### Examples

    fizzy column show abc123 --board "My Board"
EOF
  fi
}

_column_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local column_id name color created_at
  column_id=$(echo "$data" | jq -r '.id')
  name=$(echo "$data" | jq -r '.name')
  color=$(echo "$data" | jq -r '.color // empty')
  created_at=$(echo "$data" | jq -r '.created_at | split("T")[0]')

  md_heading 2 "Column: $name"
  echo
  md_kv "ID" "$column_id" \
        "Color" "${color:-"(default)"}" \
        "Created" "$created_at"

  md_breadcrumbs "$breadcrumbs"
}


# fizzy column left <id> --board <board>
# Move a column left (decrease position)

_column_left() {
  local column_id=""
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
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy column left --help"
        ;;
      *)
        if [[ -z "$column_id" ]]; then
          column_id="$1"
          shift
        else
          die "Unexpected argument: $1" $EXIT_USAGE
        fi
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _column_left_help
    return 0
  fi

  if [[ -z "$column_id" ]]; then
    die "Column ID or name required" $EXIT_USAGE "Usage: fizzy column left <id> --board <board>"
  fi

  board_id=$(_column_resolve_board "$board_id")

  local resolved_column
  if resolved_column=$(resolve_column_id "$column_id" "$board_id"); then
    column_id="$resolved_column"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy columns --board $board_id"
  fi

  # POST to left_position endpoint
  api_post "/columns/$column_id/left_position" > /dev/null

  # Fetch updated column
  local response
  response=$(api_get "/boards/$board_id/columns/$column_id")

  local column_name
  column_name=$(echo "$response" | jq -r '.name // "unknown"')

  local summary="Moved column $column_name left"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "columns" "fizzy columns --board $board_id" "List columns")" \
    "$(breadcrumb "show" "fizzy column show $column_id --board $board_id" "View column")" \
    "$(breadcrumb "right" "fizzy column right $column_id --board $board_id" "Move right")"
  )

  output "$response" "$summary" "$breadcrumbs" "_column_md"
}

_column_left_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy column left",
      description: "Move a column left (decrease position)",
      usage: "fizzy column left <id|name> --board <board>",
      options: [
        {flag: "--board, -b", description: "Board containing the column (required)"}
      ],
      examples: [
        "fizzy column left abc123 --board \"My Board\"",
        "fizzy column left \"In Progress\" --board \"My Board\""
      ]
    }'
  else
    cat <<'EOF'
## fizzy column left

Move a column left (decrease position).

### Usage

    fizzy column left <id|name> --board <board>

### Options

    --board, -b   Board containing the column (required)

### Examples

    fizzy column left abc123 --board "My Board"
    fizzy column left "In Progress" --board "My Board"
EOF
  fi
}


# fizzy column right <id> --board <board>
# Move a column right (increase position)

_column_right() {
  local column_id=""
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
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy column right --help"
        ;;
      *)
        if [[ -z "$column_id" ]]; then
          column_id="$1"
          shift
        else
          die "Unexpected argument: $1" $EXIT_USAGE
        fi
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _column_right_help
    return 0
  fi

  if [[ -z "$column_id" ]]; then
    die "Column ID or name required" $EXIT_USAGE "Usage: fizzy column right <id> --board <board>"
  fi

  board_id=$(_column_resolve_board "$board_id")

  local resolved_column
  if resolved_column=$(resolve_column_id "$column_id" "$board_id"); then
    column_id="$resolved_column"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy columns --board $board_id"
  fi

  # POST to right_position endpoint
  api_post "/columns/$column_id/right_position" > /dev/null

  # Fetch updated column
  local response
  response=$(api_get "/boards/$board_id/columns/$column_id")

  local column_name
  column_name=$(echo "$response" | jq -r '.name // "unknown"')

  local summary="Moved column $column_name right"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "columns" "fizzy columns --board $board_id" "List columns")" \
    "$(breadcrumb "show" "fizzy column show $column_id --board $board_id" "View column")" \
    "$(breadcrumb "left" "fizzy column left $column_id --board $board_id" "Move left")"
  )

  output "$response" "$summary" "$breadcrumbs" "_column_md"
}

_column_right_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy column right",
      description: "Move a column right (increase position)",
      usage: "fizzy column right <id|name> --board <board>",
      options: [
        {flag: "--board, -b", description: "Board containing the column (required)"}
      ],
      examples: [
        "fizzy column right abc123 --board \"My Board\"",
        "fizzy column right \"In Progress\" --board \"My Board\""
      ]
    }'
  else
    cat <<'EOF'
## fizzy column right

Move a column right (increase position).

### Usage

    fizzy column right <id|name> --board <board>

### Options

    --board, -b   Board containing the column (required)

### Examples

    fizzy column right abc123 --board "My Board"
    fizzy column right "In Progress" --board "My Board"
EOF
  fi
}
