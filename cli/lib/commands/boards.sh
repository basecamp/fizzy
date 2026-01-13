#!/usr/bin/env bash
# boards.sh - Board and column query commands


# fizzy boards [options]
# List boards in the account

cmd_boards() {
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
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
  response=$(api_get "/boards")

  local count
  count=$(echo "$response" | jq 'length')

  local summary="$count boards"
  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy show board <id>" "View board details")" \
    "$(breadcrumb "cards" "fizzy cards --board <id>" "List cards on board")" \
    "$(breadcrumb "columns" "fizzy columns --board <id>" "List board columns")" \
    "$(breadcrumb "create" "fizzy config set board_id <id>" "Set default board")"
  )

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
      options: [],
      examples: [
        "fizzy boards",
        "fizzy boards --json"
      ]
    }'
  else
    cat <<'EOF'
## fizzy boards

List boards in the account.

### Usage

    fizzy boards [options]

### Options

    --help, -h    Show this help

### Examples

    fizzy boards              List all boards
    fizzy boards --json       Output as JSON
    fizzy boards -q           Raw data only
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
      --board|-b)
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
        {flag: "--board, -b", description: "Board name or ID (required unless set in config)"}
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

    --board, -b   Board name or ID (required unless set in config)
    --help, -h    Show this help

### Examples

    fizzy columns --board "My Board"  List columns on board
    fizzy columns                     List columns on default board
EOF
  fi
}
