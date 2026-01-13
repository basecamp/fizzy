#!/usr/bin/env bash
# cards.sh - Card query commands


# fizzy cards [options]
# List and filter cards

cmd_cards() {
  local board_id=""
  local tag_id=""
  local assignee_id=""
  local status=""
  local search_terms=""
  local sort_by="latest"
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
      --tag)
        if [[ -z "${2:-}" ]]; then
          die "--tag requires a value" $EXIT_USAGE
        fi
        tag_id="$2"
        shift 2
        ;;
      --assignee)
        if [[ -z "${2:-}" ]]; then
          die "--assignee requires a value" $EXIT_USAGE
        fi
        assignee_id="$2"
        shift 2
        ;;
      --status)
        if [[ -z "${2:-}" ]]; then
          die "--status requires a value" $EXIT_USAGE
        fi
        status="$2"
        shift 2
        ;;
      --search|-s)
        if [[ -z "${2:-}" ]]; then
          die "--search requires a value" $EXIT_USAGE
        fi
        search_terms="$2"
        shift 2
        ;;
      --sort)
        if [[ -z "${2:-}" ]]; then
          die "--sort requires a value" $EXIT_USAGE
        fi
        sort_by="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      *)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy cards --help"
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _cards_help
    return 0
  fi

  # Build query parameters
  local path="/cards"
  local params=()

  # Use provided board_id or fall back to config
  if [[ -z "$board_id" ]]; then
    board_id=$(get_board_id 2>/dev/null || true)
  fi

  # Resolve board name to ID if needed
  if [[ -n "$board_id" ]]; then
    local resolved_board
    if resolved_board=$(resolve_board_id "$board_id"); then
      board_id="$resolved_board"
    else
      die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy boards"
    fi
    params+=("board_ids[]=$board_id")
  fi

  # Resolve tag name to ID if needed
  if [[ -n "$tag_id" ]]; then
    local resolved_tag
    if resolved_tag=$(resolve_tag_id "$tag_id"); then
      tag_id="$resolved_tag"
    else
      die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy tags"
    fi
    params+=("tag_ids[]=$tag_id")
  fi

  # Resolve assignee name/email to ID if needed
  if [[ -n "$assignee_id" ]]; then
    local resolved_user
    if resolved_user=$(resolve_user_id "$assignee_id"); then
      assignee_id="$resolved_user"
    else
      die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy people"
    fi
    params+=("assignee_ids[]=$assignee_id")
  fi

  if [[ -n "$status" ]]; then
    params+=("indexed_by=$status")
  fi

  if [[ -n "$search_terms" ]]; then
    # Split search terms by space and add each as a separate terms[] param
    local term
    for term in $search_terms; do
      local encoded_term
      encoded_term=$(urlencode "$term")
      params+=("terms[]=$encoded_term")
    done
  fi

  if [[ -n "$sort_by" ]]; then
    params+=("sorted_by=$sort_by")
  fi

  # Build query string
  if [[ ${#params[@]} -gt 0 ]]; then
    local query_string
    query_string=$(IFS='&'; echo "${params[*]}")
    path="$path?$query_string"
  fi

  local response
  response=$(api_get "$path")

  local count
  count=$(echo "$response" | jq 'length')

  local summary="$count cards"
  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy show <number>" "View card details")" \
    "$(breadcrumb "create" "fizzy card \"title\"" "Create new card")" \
    "$(breadcrumb "filter" "fizzy cards --status closed" "Filter by status")" \
    "$(breadcrumb "search" "fizzy search \"query\"" "Search cards")"
  )

  output "$response" "$summary" "$breadcrumbs" "_cards_md"
}

_cards_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  md_heading 2 "Cards ($summary)"

  local count
  count=$(echo "$data" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No cards found."
    echo
  else
    echo "| # | Title | Board | Status | Tags |"
    echo "|---|-------|-------|--------|------|"
    echo "$data" | jq -r '.[] | "| \(.number) | \(.title // .description[0:40]) | \(.board.name) | \(if .closed then "Closed" elif .column then .column.name else "Triage" end) | \(.tags | join(", ")) |"'
    echo
  fi

  md_breadcrumbs "$breadcrumbs"
}

_cards_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy cards",
      description: "List and filter cards",
      options: [
        {flag: "--board, -b", description: "Filter by board name or ID"},
        {flag: "--tag", description: "Filter by tag name or ID"},
        {flag: "--assignee", description: "Filter by assignee name, email, or ID"},
        {flag: "--status", description: "Filter by status: all, closed, not_now, stalled, golden"},
        {flag: "--search, -s", description: "Search terms"},
        {flag: "--sort", description: "Sort order: latest, newest, oldest"}
      ],
      examples: [
        "fizzy cards",
        "fizzy cards --board \"My Board\"",
        "fizzy cards --assignee \"Jane Doe\"",
        "fizzy cards --search \"bug fix\"",
        "fizzy cards --status closed"
      ]
    }'
  else
    cat <<'EOF'
## fizzy cards

List and filter cards.

### Usage

    fizzy cards [options]

### Options

    --board, -b   Filter by board name or ID
    --tag         Filter by tag name or ID
    --assignee    Filter by assignee name, email, or ID
    --status      Filter: all, closed, not_now, stalled, golden
    --search, -s  Search terms
    --sort        Sort: latest (default), newest, oldest
    --help, -h    Show this help

### Examples

    fizzy cards                        List all cards
    fizzy cards --board "My Board"     Filter by board name
    fizzy cards --assignee "Jane"      Filter by assignee name
    fizzy cards --search "bug"         Search for cards
    fizzy cards --status closed        Show closed cards
EOF
  fi
}


# Show card details (called by cmd_show)
show_card() {
  local card_number="$1"

  if [[ -z "$card_number" ]]; then
    die "Card number required" $EXIT_USAGE "Usage: fizzy show <number>"
  fi

  local response
  response=$(api_get "/cards/$card_number")

  local title
  title=$(echo "$response" | jq -r '.title // .description[0:50]')
  local summary="Card #$card_number: $title"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "close" "fizzy close $card_number" "Close this card")" \
    "$(breadcrumb "comment" "fizzy comment \"text\" --on $card_number" "Add comment")" \
    "$(breadcrumb "assign" "fizzy assign $card_number --to <user_id>" "Assign user")" \
    "$(breadcrumb "triage" "fizzy triage $card_number --to <column_id>" "Move to column")"
  )

  output "$response" "$summary" "$breadcrumbs" "_show_card_md"
}

_show_card_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local number title board_name column_name status creator_name created_at
  local description tags golden assignees

  number=$(echo "$data" | jq -r '.number')
  title=$(echo "$data" | jq -r '.title // ""')
  board_name=$(echo "$data" | jq -r '.board.name')
  column_name=$(echo "$data" | jq -r '.column.name // "Triage"')
  status=$(echo "$data" | jq -r 'if .closed then "Closed" else "Active" end')
  creator_name=$(echo "$data" | jq -r '.creator.name')
  created_at=$(echo "$data" | jq -r '.created_at | split("T")[0]')
  description=$(echo "$data" | jq -r '.description // ""')
  tags=$(echo "$data" | jq -r '.tags | join(", ")')
  golden=$(echo "$data" | jq -r 'if .golden then "Yes" else "No" end')

  md_heading 2 "Card #$number${title:+: $title}"

  md_kv "Board" "$board_name" \
        "Column" "$column_name" \
        "Status" "$status" \
        "Golden" "$golden" \
        "Tags" "${tags:-None}" \
        "Created" "$created_at by $creator_name"

  if [[ -n "$description" ]]; then
    echo "### Description"
    echo
    echo "$description"
    echo
  fi

  # Show steps if present
  local steps_count
  steps_count=$(echo "$data" | jq '.steps | length // 0')
  if [[ "$steps_count" -gt 0 ]]; then
    echo "### Steps ($steps_count)"
    echo
    echo "$data" | jq -r '.steps[] | "- [\(if .completed then "x" else " " end)] \(.content)"'
    echo
  fi

  md_breadcrumbs "$breadcrumbs"
}
