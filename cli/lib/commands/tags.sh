#!/usr/bin/env bash
# tags.sh - Tag query commands


# fizzy tags [options]
# List tags in the account

cmd_tags() {
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      *)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy tags --help"
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _tags_help
    return 0
  fi

  local response
  response=$(api_get "/tags")

  local count
  count=$(echo "$response" | jq 'length')

  local summary="$count tags"
  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "filter" "fizzy cards --tag <id>" "Filter cards by tag")" \
    "$(breadcrumb "add" "fizzy tag <card> --with \"name\"" "Add tag to card")"
  )

  output "$response" "$summary" "$breadcrumbs" "_tags_md"
}

_tags_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  md_heading 2 "Tags ($summary)"

  local count
  count=$(echo "$data" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No tags found."
    echo
  else
    echo "| ID | Title | Created |"
    echo "|----|-------|---------|"
    echo "$data" | jq -r '.[] | "| \(.id) | #\(.title) | \(.created_at | split("T")[0]) |"'
    echo
  fi

  md_breadcrumbs "$breadcrumbs"
}

_tags_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy tags",
      description: "List tags in the account",
      options: [],
      examples: [
        "fizzy tags",
        "fizzy tags --json"
      ]
    }'
  else
    cat <<'EOF'
## fizzy tags

List tags in the account.

### Usage

    fizzy tags [options]

### Options

    --help, -h    Show this help

### Examples

    fizzy tags              List all tags
    fizzy tags --json       Output as JSON
    fizzy tags -q           Raw data only
EOF
  fi
}
