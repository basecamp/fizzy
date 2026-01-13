#!/usr/bin/env bash
# tags.sh - Tag query commands


# fizzy tags [options]
# List tags in the account

cmd_tags() {
  local show_help=false
  local page=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
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
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy tags --help"
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _tags_help
    return 0
  fi

  local path="/tags"
  if [[ -n "$page" ]]; then
    path="$path?page=$page"
  fi

  local response
  response=$(api_get "$path")

  local count
  count=$(echo "$response" | jq 'length')

  local summary="$count tags"
  [[ -n "$page" ]] && summary="$count tags (page $page)"

  local next_page=$((${page:-1} + 1))
  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "filter" "fizzy cards --tag <id>" "Filter cards by tag")" \
    "$(breadcrumb "add" "fizzy tag <card> --with \"name\"" "Add tag to card")" \
    "$(breadcrumb "next" "fizzy tags --page $next_page" "Next page")"
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
      options: [
        {flag: "--page, -p", description: "Page number for pagination"}
      ],
      examples: [
        "fizzy tags",
        "fizzy tags --page 2"
      ]
    }'
  else
    cat <<'EOF'
## fizzy tags

List tags in the account.

### Usage

    fizzy tags [options]

### Options

    --page, -p    Page number for pagination
    --help, -h    Show this help

### Examples

    fizzy tags              List all tags
    fizzy tags --page 2     Get second page
EOF
  fi
}
