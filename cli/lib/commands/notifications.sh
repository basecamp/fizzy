#!/usr/bin/env bash
# notifications.sh - Notification query and action commands


# fizzy notifications [options]
# List notifications

cmd_notifications() {
  local action=""
  local show_help=false
  local page=""
  local fetch_all=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all|-a)
        fetch_all=true
        shift
        ;;
      read|unread)
        action="$1"
        shift
        _notifications_action "$action" "$@"
        return
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
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy notifications --help"
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _notifications_help
    return 0
  fi

  local response
  if [[ "$fetch_all" == "true" ]]; then
    response=$(api_get_all "/notifications")
  else
    local path="/notifications"
    if [[ -n "$page" ]]; then
      path="$path?page=$page"
    fi
    response=$(api_get "$path")
  fi

  local count unread_count
  count=$(echo "$response" | jq 'length')
  unread_count=$(echo "$response" | jq '[.[] | select(.read == false)] | length')

  local summary="$count notifications ($unread_count unread)"
  [[ -n "$page" ]] && summary="$count notifications ($unread_count unread, page $page)"
  [[ "$fetch_all" == "true" ]] && summary="$count notifications ($unread_count unread, all)"

  local next_page=$((${page:-1} + 1))
  local breadcrumbs
  if [[ "$fetch_all" == "true" ]]; then
    breadcrumbs=$(breadcrumbs \
      "$(breadcrumb "read" "fizzy notifications read <id>" "Mark as read")" \
      "$(breadcrumb "read-all" "fizzy notifications read --all" "Mark all as read")" \
      "$(breadcrumb "show" "fizzy show <card_number>" "View card")"
    )
  else
    breadcrumbs=$(breadcrumbs \
      "$(breadcrumb "read" "fizzy notifications read <id>" "Mark as read")" \
      "$(breadcrumb "read-all" "fizzy notifications read --all" "Mark all as read")" \
      "$(breadcrumb "show" "fizzy show <card_number>" "View card")" \
      "$(breadcrumb "next" "fizzy notifications --page $next_page" "Next page")"
    )
  fi

  output "$response" "$summary" "$breadcrumbs" "_notifications_md"
}

_notifications_action() {
  local action="$1"
  shift

  local notification_id=""
  local all=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)
        all=true
        shift
        ;;
      *)
        if [[ -z "$notification_id" ]]; then
          notification_id="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$action" == "read" ]]; then
    if [[ "$all" == "true" ]]; then
      api_post "/notifications/bulk_reading"
      info "All notifications marked as read"
    elif [[ -n "$notification_id" ]]; then
      api_post "/notifications/$notification_id/reading"
      info "Notification marked as read"
    else
      die "Notification ID required" $EXIT_USAGE "Usage: fizzy notifications read <id> or --all"
    fi
  elif [[ "$action" == "unread" ]]; then
    if [[ -z "$notification_id" ]]; then
      die "Notification ID required" $EXIT_USAGE "Usage: fizzy notifications unread <id>"
    fi
    api_delete "/notifications/$notification_id/reading"
    info "Notification marked as unread"
  fi
}

_notifications_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  md_heading 2 "Notifications"
  echo "*$summary*"
  echo

  local count
  count=$(echo "$data" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No notifications."
    echo
  else
    echo "| Status | Card | Title | From | Date |"
    echo "|--------|------|-------|------|------|"
    echo "$data" | jq -r '.[] | "| \(if .read then "Read" else "**Unread**" end) | #\(.card.id[0:8]) | \(.title[0:30]) | \(.creator.name) | \(.created_at | split("T")[0]) |"'
    echo
  fi

  md_breadcrumbs "$breadcrumbs"
}

_notifications_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy notifications",
      description: "List and manage notifications",
      subcommands: [
        {name: "read", description: "Mark notification as read"},
        {name: "unread", description: "Mark notification as unread"}
      ],
      options: [
        {flag: "--all, -a", description: "Fetch all pages"},
        {flag: "--page, -p", description: "Page number for pagination"},
        {flag: "--all (with read)", description: "Mark all notifications as read"}
      ],
      examples: [
        "fizzy notifications",
        "fizzy notifications --all",
        "fizzy notifications --page 2",
        "fizzy notifications read abc123",
        "fizzy notifications read --all"
      ]
    }'
  else
    cat <<'EOF'
## fizzy notifications

List and manage notifications.

### Usage

    fizzy notifications              List notifications
    fizzy notifications --all        Fetch all pages
    fizzy notifications --page 2     Get second page
    fizzy notifications read <id>    Mark as read
    fizzy notifications read --all   Mark all as read
    fizzy notifications unread <id>  Mark as unread

### Options

    --all, -a     Fetch all pages
    --page, -p    Page number for pagination

### Examples

    fizzy notifications              List notifications (first page)
    fizzy notifications --all        Fetch all notifications
    fizzy notifications --page 2     Get second page
    fizzy notifications read abc123  Mark notification as read
    fizzy notifications read --all   Mark all as read
EOF
  fi
}
