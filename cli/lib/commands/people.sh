#!/usr/bin/env bash
# people.sh - User query commands


# fizzy people [options]
# List users in the account

cmd_people() {
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
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

  local response
  response=$(api_get "/users")

  local count
  count=$(echo "$response" | jq 'length')

  local summary="$count users"
  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "assign" "fizzy assign <card> --to <user_id>" "Assign user to card")" \
    "$(breadcrumb "cards" "fizzy cards --assignee <user_id>" "Cards assigned to user")"
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
      options: [],
      examples: [
        "fizzy people",
        "fizzy people --json"
      ]
    }'
  else
    cat <<'EOF'
## fizzy people

List users in the account.

### Usage

    fizzy people [options]

### Options

    --help, -h    Show this help

### Examples

    fizzy people              List all users
    fizzy people --json       Output as JSON
    fizzy people -q           Raw data only
EOF
  fi
}
