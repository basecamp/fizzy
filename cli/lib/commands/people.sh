#!/usr/bin/env bash
# people.sh - User query commands


# fizzy people [options]
# List users in the account

cmd_people() {
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
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy people --help"
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _people_help
    return 0
  fi

  local path="/users"
  if [[ -n "$page" ]]; then
    path="$path?page=$page"
  fi

  local response
  response=$(api_get "$path")

  local count
  count=$(echo "$response" | jq 'length')

  local summary="$count users"
  [[ -n "$page" ]] && summary="$count users (page $page)"

  local next_page=$((${page:-1} + 1))
  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "assign" "fizzy assign <card> --to <user_id>" "Assign user to card")" \
    "$(breadcrumb "cards" "fizzy cards --assignee <user_id>" "Cards assigned to user")" \
    "$(breadcrumb "next" "fizzy people --page $next_page" "Next page")"
  )

  output "$response" "$summary" "$breadcrumbs" "_people_md"
}

_people_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  md_heading 2 "People ($summary)"

  local count
  count=$(echo "$data" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No users found."
    echo
  else
    echo "| ID | Name | Email | Role |"
    echo "|----|------|-------|------|"
    echo "$data" | jq -r '.[] | "| \(.id) | \(.name) | \(.email_address) | \(.role) |"'
    echo
  fi

  md_breadcrumbs "$breadcrumbs"
}

_people_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy people",
      description: "List users in the account",
      options: [
        {flag: "--page, -p", description: "Page number for pagination"}
      ],
      examples: [
        "fizzy people",
        "fizzy people --page 2"
      ]
    }'
  else
    cat <<'EOF'
## fizzy people

List users in the account.

### Usage

    fizzy people [options]

### Options

    --page, -p    Page number for pagination
    --help, -h    Show this help

### Examples

    fizzy people              List all users
    fizzy people --page 2     Get second page
EOF
  fi
}
