#!/usr/bin/env bash
# show.sh - Show detail view dispatcher


# fizzy show <type> <id>
# Show detailed view of a resource

cmd_show() {
  if [[ $# -eq 0 ]]; then
    _show_help
    return 0
  fi

  local first_arg="$1"
  shift

  case "$first_arg" in
    --help|-h)
      _show_help
      ;;
    board)
      show_board "$@"
      ;;
    card)
      show_card "$@"
      ;;
    *)
      # If first arg looks like a number, assume it's a card number
      if [[ "$first_arg" =~ ^[0-9]+$ ]]; then
        show_card "$first_arg"
      else
        # Otherwise treat as board ID
        show_board "$first_arg"
      fi
      ;;
  esac
}

# Show board details
show_board() {
  local board_id="$1"

  if [[ -z "$board_id" ]]; then
    die "Board ID required" $EXIT_USAGE "Usage: fizzy show board <id>"
  fi

  local response
  response=$(api_get "/boards/$board_id")

  local name
  name=$(echo "$response" | jq -r '.name')
  local summary="Board: $name"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "cards" "fizzy cards --board $board_id" "List cards")" \
    "$(breadcrumb "columns" "fizzy columns --board $board_id" "List columns")" \
    "$(breadcrumb "set" "fizzy config set board_id $board_id" "Set as default")"
  )

  output "$response" "$summary" "$breadcrumbs" "_show_board_md"
}

_show_board_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local id name all_access creator_name created_at

  id=$(echo "$data" | jq -r '.id')
  name=$(echo "$data" | jq -r '.name')
  all_access=$(echo "$data" | jq -r 'if .all_access then "Yes (all users)" else "Selective" end')
  creator_name=$(echo "$data" | jq -r '.creator.name')
  created_at=$(echo "$data" | jq -r '.created_at | split("T")[0]')

  md_heading 2 "Board: $name"

  md_kv "ID" "$id" \
        "Access" "$all_access" \
        "Created" "$created_at by $creator_name"

  md_breadcrumbs "$breadcrumbs"
}

_show_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy show",
      description: "Show detailed view of a resource",
      usage: [
        "fizzy show <card_number>",
        "fizzy show card <number>",
        "fizzy show board <id>"
      ],
      examples: [
        "fizzy show 42",
        "fizzy show card 42",
        "fizzy show board abc123"
      ]
    }'
  else
    cat <<'EOF'
## fizzy show

Show detailed view of a resource.

### Usage

    fizzy show <card_number>      Show card by number
    fizzy show card <number>      Show card by number
    fizzy show board <id>         Show board by ID

### Examples

    fizzy show 42                 Show card #42
    fizzy show card 42            Show card #42
    fizzy show board abc123       Show board details
EOF
  fi
}
