#!/usr/bin/env bash
# comments.sh - Comment query and action commands


# fizzy comments [options]
# List comments on a card

cmd_comments() {
  local card_number=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on)
        if [[ -z "${2:-}" ]]; then
          die "--on requires a card number" $EXIT_USAGE
        fi
        card_number="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      *)
        # First positional arg could be card number
        if [[ -z "$card_number" ]] && [[ "$1" =~ ^[0-9]+$ ]]; then
          card_number="$1"
          shift
        else
          die "Unknown option: $1" $EXIT_USAGE "Run: fizzy comments --help"
        fi
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _comments_help
    return 0
  fi

  if [[ -z "$card_number" ]]; then
    die "Card number required" $EXIT_USAGE "Usage: fizzy comments --on <number>"
  fi

  local response
  response=$(api_get "/cards/$card_number/comments")

  local count
  count=$(echo "$response" | jq 'length')

  local summary="$count comments on card #$card_number"
  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "add" "fizzy comment \"text\" --on $card_number" "Add comment")" \
    "$(breadcrumb "react" "fizzy react \"👍\" --on <comment_id>" "Add reaction")" \
    "$(breadcrumb "show" "fizzy show $card_number" "View card")"
  )

  output "$response" "$summary" "$breadcrumbs" "_comments_md"
}

_comments_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  md_heading 2 "Comments"
  echo "*$summary*"
  echo

  local count
  count=$(echo "$data" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No comments yet."
    echo
  else
    echo "| ID | Author | Date | Comment |"
    echo "|----|--------|------|---------|"
    echo "$data" | jq -r '.[] | "| \(.id[0:12])... | \(.creator.name) | \(.created_at | split("T")[0]) | \((.body.plain_text // "(no text)")[0:40] | gsub("\n"; " "))... |"'
    echo
  fi

  md_breadcrumbs "$breadcrumbs"
}

_comments_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy comments",
      description: "List comments on a card",
      usage: "fizzy comments --on <card_number>",
      options: [
        {flag: "--on", description: "Card number to list comments for"}
      ],
      examples: [
        "fizzy comments --on 42",
        "fizzy comments 42"
      ]
    }'
  else
    cat <<'EOF'
## fizzy comments

List comments on a card.

### Usage

    fizzy comments --on <card_number>
    fizzy comments <card_number>

### Options

    --on          Card number to list comments for
    --help, -h    Show this help

### Examples

    fizzy comments --on 42    List comments on card #42
    fizzy comments 42         List comments on card #42
EOF
  fi
}


# fizzy reactions --card <number> --comment <id>
# List reactions on a comment

cmd_reactions() {
  local card_number=""
  local comment_id=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --card)
        if [[ -z "${2:-}" ]]; then
          die "--card requires a card number" $EXIT_USAGE
        fi
        card_number="$2"
        shift 2
        ;;
      --comment)
        if [[ -z "${2:-}" ]]; then
          die "--comment requires a comment ID" $EXIT_USAGE
        fi
        comment_id="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy reactions --help"
        ;;
      *)
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _reactions_help
    return 0
  fi

  if [[ -z "$card_number" ]]; then
    die "--card number required" $EXIT_USAGE "Usage: fizzy reactions --card <num> --comment <id>"
  fi

  if [[ -z "$comment_id" ]]; then
    die "--comment ID required" $EXIT_USAGE "Usage: fizzy reactions --card <num> --comment <id>"
  fi

  local response
  response=$(api_get "/cards/$card_number/comments/$comment_id/reactions")

  local count
  count=$(echo "$response" | jq 'length')

  local summary="$count reactions on comment"
  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "react" "fizzy react \"👍\" --card $card_number --comment $comment_id" "Add reaction")" \
    "$(breadcrumb "comments" "fizzy comments --on $card_number" "View comments")" \
    "$(breadcrumb "show" "fizzy show $card_number" "View card")"
  )

  output "$response" "$summary" "$breadcrumbs" "_reactions_md"
}

_reactions_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  md_heading 2 "Reactions"
  echo "*$summary*"
  echo

  local count
  count=$(echo "$data" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No reactions yet."
    echo
  else
    echo "| ID | Emoji | By |"
    echo "|----|-------|----|"
    echo "$data" | jq -r '.[] | "| \(.id[0:12])... | \(.content) | \(.reacter.name) |"'
    echo
  fi

  md_breadcrumbs "$breadcrumbs"
}

_reactions_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy reactions",
      description: "List reactions on a comment",
      usage: "fizzy reactions --card <num> --comment <id>",
      options: [
        {flag: "--card", description: "Card number"},
        {flag: "--comment", description: "Comment ID"}
      ],
      examples: [
        "fizzy reactions --card 123 --comment abc456"
      ]
    }'
  else
    cat <<'EOF'
## fizzy reactions

List reactions on a comment.

### Usage

    fizzy reactions --card <num> --comment <id>

### Options

    --card        Card number (required)
    --comment     Comment ID (required)
    --help, -h    Show this help

### Examples

    fizzy reactions --card 123 --comment abc456
EOF
  fi
}
