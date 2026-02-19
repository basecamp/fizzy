#!/usr/bin/env bash
# search.sh - Search commands


# fizzy search <query> [options]
# Search cards

cmd_search() {
  local query=""
  local board_id=""
  local show_help=false

  # First non-flag argument is the query
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
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy search --help"
        ;;
      *)
        if [[ -z "$query" ]]; then
          query="$1"
        else
          # Append additional words to query
          query="$query $1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _search_help
    return 0
  fi

  if [[ -z "$query" ]]; then
    die "Search query required" $EXIT_USAGE "Usage: fizzy search \"your query\""
  fi

  # Build query parameters
  local path="/cards"
  local params=()

  # Split and URL encode each search term
  local term
  for term in $query; do
    local encoded_term
    encoded_term=$(urlencode "$term")
    params+=("terms[]=$encoded_term")
  done

  # Use provided board_id or fall back to config
  if [[ -z "$board_id" ]]; then
    board_id=$(get_board_id 2>/dev/null || true)
  fi

  # Resolve board name to ID if provided
  if [[ -n "$board_id" ]]; then
    local resolved_board
    if resolved_board=$(resolve_board_id "$board_id"); then
      board_id="$resolved_board"
    else
      die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy boards"
    fi
    params+=("board_ids[]=$board_id")
  fi

  # Build query string
  local query_string
  query_string=$(IFS='&'; echo "${params[*]}")
  path="$path?$query_string"

  local response
  response=$(api_get "$path")

  local count
  count=$(echo "$response" | jq 'length')

  local summary="$count results for \"$query\""
  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy show <number>" "View card details")" \
    "$(breadcrumb "narrow" "fizzy search \"$query\" --board <id>" "Filter by board")"
  )

  output "$response" "$summary" "$breadcrumbs" "_search_md"
}

_search_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  md_heading 2 "Search Results"
  echo "*$summary*"
  echo

  local count
  count=$(echo "$data" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No cards found matching your search."
    echo
  else
    echo "| # | Title | Board | Status |"
    echo "|---|-------|-------|--------|"
    echo "$data" | jq -r '.[] | "| \(.number) | \(.title // .description[0:40]) | \(.board.name) | \(if .closed then "Closed" elif .column then .column.name else "Triage" end) |"'
    echo
  fi

  md_breadcrumbs "$breadcrumbs"
}

_search_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy search",
      description: "Search cards",
      usage: "fizzy search <query> [options]",
      options: [
        {flag: "--board, -b, --in", description: "Filter results to a specific board"}
      ],
      examples: [
        "fizzy search \"bug fix\"",
        "fizzy search login --board abc123"
      ]
    }'
  else
    cat <<'EOF'
## fizzy search

Search cards by keywords.

### Usage

    fizzy search <query> [options]

### Options

    --board, -b, --in   Filter results to a specific board
    --help, -h    Show this help

### Examples

    fizzy search "bug fix"              Search all cards
    fizzy search login --board abc123   Search within board
EOF
  fi
}
