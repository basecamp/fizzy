#!/usr/bin/env bash
# actions.sh - Card action commands (Phase 3)


# fizzy card "title" [options]
# Create a new card

cmd_card_create() {
  local title=""
  local description=""
  local board_id=""
  local column_id=""
  local tag_names=()
  local assignee_ids=()
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --board|-b|--in)
        if [[ -z "${2:-}" ]]; then
          die "--board requires a board name or ID" $EXIT_USAGE
        fi
        board_id="$2"
        shift 2
        ;;
      --column|-c)
        if [[ -z "${2:-}" ]]; then
          die "--column requires a column name or ID" $EXIT_USAGE
        fi
        column_id="$2"
        shift 2
        ;;
      --description|-d)
        if [[ -z "${2:-}" ]]; then
          die "--description requires text" $EXIT_USAGE
        fi
        description="$2"
        shift 2
        ;;
      --tag)
        if [[ -z "${2:-}" ]]; then
          die "--tag requires a tag name" $EXIT_USAGE
        fi
        # Store tag name (strip leading # if present) for taggings API
        tag_names+=("${2#\#}")
        shift 2
        ;;
      --assign)
        if [[ -z "${2:-}" ]]; then
          die "--assign requires a user name or ID" $EXIT_USAGE
        fi
        assignee_ids+=("$2")
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy card --help"
        ;;
      *)
        # First positional arg is title
        if [[ -z "$title" ]]; then
          title="$1"
          shift
        else
          die "Unexpected argument: $1" $EXIT_USAGE
        fi
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _card_create_help
    return 0
  fi

  if [[ -z "$title" ]]; then
    die "Card title required" $EXIT_USAGE "Usage: fizzy card \"title\""
  fi

  # Use board from config if not specified
  if [[ -z "$board_id" ]]; then
    board_id=$(get_board_id 2>/dev/null || true)
  fi

  if [[ -z "$board_id" ]]; then
    die "No board specified. Use --board or set in .fizzy/config.json" $EXIT_USAGE
  fi

  # Resolve board name to ID
  local resolved_board
  if resolved_board=$(resolve_board_id "$board_id"); then
    board_id="$resolved_board"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy boards"
  fi

  # Resolve column name to ID if provided (for triage follow-up)
  if [[ -n "$column_id" ]]; then
    local resolved_column
    if resolved_column=$(resolve_column_id "$column_id" "$board_id"); then
      column_id="$resolved_column"
    else
      die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy columns --board $board_id"
    fi
  fi

  # Resolve assignee names to IDs (for assignment follow-up)
  local resolved_assignee_ids=()
  for assignee in "${assignee_ids[@]}"; do
    local resolved_user
    if resolved_user=$(resolve_user_id "$assignee"); then
      resolved_assignee_ids+=("$resolved_user")
    else
      die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy people"
    fi
  done
  assignee_ids=("${resolved_assignee_ids[@]}")

  # Build request body (API only accepts title, description)
  local body
  body=$(jq -n \
    --arg title "$title" \
    --arg description "${description:-}" \
    '{title: $title} +
     (if $description != "" then {description: $description} else {} end)')

  local response
  response=$(api_post "/boards/$board_id/cards" "$body")

  local number
  number=$(echo "$response" | jq -r '.number')

  # Chain follow-up actions after card creation
  local actions_taken=()

  # Triage to column if specified
  if [[ -n "$column_id" ]]; then
    local triage_body
    triage_body=$(jq -n --arg column_id "$column_id" '{column_id: $column_id}')
    api_post "/cards/$number/triage" "$triage_body" > /dev/null
    actions_taken+=("triaged")
  fi

  # Add tags if specified
  for tag_name in "${tag_names[@]}"; do
    local tag_body
    tag_body=$(jq -n --arg tag_title "$tag_name" '{tag_title: $tag_title}')
    api_post "/cards/$number/taggings" "$tag_body" > /dev/null
    actions_taken+=("tagged #$tag_name")
  done

  # Add assignments if specified
  for assignee_id in "${assignee_ids[@]}"; do
    local assign_body
    assign_body=$(jq -n --arg assignee_id "$assignee_id" '{assignee_id: $assignee_id}')
    api_post "/cards/$number/assignments" "$assign_body" > /dev/null
    actions_taken+=("assigned")
  done

  # Fetch updated card if we made any follow-up changes
  if [[ ${#actions_taken[@]} -gt 0 ]]; then
    response=$(api_get "/cards/$number")
  fi

  local summary="Created card #$number"
  if [[ ${#actions_taken[@]} -gt 0 ]]; then
    summary="Created card #$number (${actions_taken[*]})"
  fi

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy show $number" "View card details")" \
    "$(breadcrumb "triage" "fizzy triage $number --to <column_id>" "Move to column")" \
    "$(breadcrumb "comment" "fizzy comment \"text\" --on $number" "Add comment")"
  )

  output "$response" "$summary" "$breadcrumbs" "_card_created_md"
}

_card_created_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local number title board_name
  number=$(echo "$data" | jq -r '.number')
  title=$(echo "$data" | jq -r '.title // .description[0:50]')
  board_name=$(echo "$data" | jq -r '.board.name')

  md_heading 2 "Card Created"
  echo
  md_kv "Number" "#$number" \
        "Title" "$title" \
        "Board" "$board_name"

  md_breadcrumbs "$breadcrumbs"
}

_card_create_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy card",
      description: "Create a new card with optional follow-up actions",
      usage: "fizzy card \"title\" [options]",
      options: [
        {flag: "--board, -b, --in", description: "Board name or ID (required if not in config)"},
        {flag: "--column, -c", description: "Column name or ID (chains triage after create)"},
        {flag: "--description, -d", description: "Card description"},
        {flag: "--tag", description: "Tag name (chains tagging after create, repeatable)"},
        {flag: "--assign", description: "Assignee name/email/ID (chains assignment after create, repeatable)"}
      ],
      notes: "--column, --tag, and --assign execute follow-up API calls after card creation",
      examples: [
        "fizzy card \"Fix login bug\"",
        "fizzy card \"New feature\" --board \"My Board\" --column \"In Progress\"",
        "fizzy card \"Task\" --tag bug --assign \"Jane Doe\""
      ]
    }'
  else
    cat <<'EOF'
## fizzy card

Create a new card with optional follow-up actions.

### Usage

    fizzy card "title" [options]

### Options

    --board, -b, --in    Board name or ID (required if not in config)
    --column, -c         Column name or ID (chains triage after create)
    --description, -d    Card description
    --tag                Tag name (chains tagging, repeatable)
    --assign             Assignee name/email/ID (chains assignment, repeatable)
    --help, -h           Show this help

Note: --column, --tag, and --assign trigger follow-up API calls after the
card is created, since the create endpoint only accepts title and description.

### Examples

    fizzy card "Fix login bug"
    fizzy card "New feature" --board "My Board" --column "In Progress"
    fizzy card "Task" --tag bug --tag urgent --assign "Jane Doe"
EOF
  fi
}


# fizzy update <number> [options]
# Update a card's title or description

cmd_card_update() {
  local card_number=""
  local title=""
  local description=""
  local description_file=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title|-t)
        if [[ -z "${2:-}" ]]; then
          die "--title requires a value" $EXIT_USAGE
        fi
        title="$2"
        shift 2
        ;;
      --description|-d)
        if [[ -z "${2:-}" ]]; then
          die "--description requires text" $EXIT_USAGE
        fi
        description="$2"
        shift 2
        ;;
      --description-file)
        if [[ -z "${2:-}" ]]; then
          die "--description-file requires a file path" $EXIT_USAGE
        fi
        description_file="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy update --help"
        ;;
      *)
        # First positional arg is card number
        if [[ -z "$card_number" ]]; then
          card_number="$1"
          shift
        else
          die "Unexpected argument: $1" $EXIT_USAGE
        fi
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _card_update_help
    return 0
  fi

  if [[ -z "$card_number" ]]; then
    die "Card number required" $EXIT_USAGE "Usage: fizzy update <number> [options]"
  fi

  # Read description from file if specified
  if [[ -n "$description_file" ]]; then
    if [[ ! -f "$description_file" ]]; then
      die "File not found: $description_file" $EXIT_USAGE
    fi
    description=$(cat "$description_file")
  fi

  # Must specify at least one thing to update
  if [[ -z "$title" && -z "$description" ]]; then
    die "Nothing to update. Specify --title or --description" $EXIT_USAGE
  fi

  # Build request body
  local body
  body=$(jq -n \
    --arg title "$title" \
    --arg description "$description" \
    '(if $title != "" then {title: $title} else {} end) +
     (if $description != "" then {description: $description} else {} end)')

  local response
  response=$(api_patch "/cards/$card_number" "$body")

  local summary="Card #$card_number updated"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy show $card_number" "View card details")" \
    "$(breadcrumb "triage" "fizzy triage $card_number --to <column>" "Move to column")" \
    "$(breadcrumb "comment" "fizzy comment \"text\" --on $card_number" "Add comment")"
  )

  output "$response" "$summary" "$breadcrumbs" "_card_updated_md"
}

_card_updated_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local number title board_name
  number=$(echo "$data" | jq -r '.number')
  title=$(echo "$data" | jq -r '.title // .description[0:50]')
  board_name=$(echo "$data" | jq -r '.board.name')

  md_heading 2 "Card Updated"
  echo
  md_kv "Number" "#$number" \
        "Title" "$title" \
        "Board" "$board_name"

  md_breadcrumbs "$breadcrumbs"
}

_card_update_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy update",
      description: "Update a card'\''s title or description",
      usage: "fizzy update <number> [options]",
      options: [
        {flag: "--title, -t", description: "New card title"},
        {flag: "--description, -d", description: "New card description (HTML)"},
        {flag: "--description-file", description: "Read description from file"}
      ],
      examples: [
        "fizzy update 123 --title \"New title\"",
        "fizzy update 123 --description \"<p>Updated content</p>\"",
        "fizzy update 123 --title \"New\" --description \"Both\""
      ]
    }'
  else
    cat <<'EOF'
## fizzy update

Update a card's title or description.

### Usage

    fizzy update <number> [options]

### Options

    --title, -t           New card title
    --description, -d     New card description (HTML)
    --description-file    Read description from file
    --help, -h            Show this help

### Examples

    fizzy update 123 --title "New title"
    fizzy update 123 --description "<p>Updated content</p>"
    fizzy update 123 --title "New" --description "Both"
    fizzy update 123 --description-file notes.html
EOF
  fi
}


# fizzy close <number>
# Close a card

cmd_close() {
  local show_help=false
  local card_numbers=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy close --help"
        ;;
      *)
        card_numbers+=("$1")
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _close_help
    return 0
  fi

  if [[ ${#card_numbers[@]} -eq 0 ]]; then
    die "Card number required" $EXIT_USAGE "Usage: fizzy close <number> [numbers...]"
  fi

  local results=()
  local num
  for num in "${card_numbers[@]}"; do
    # POST closure returns 204 No Content, so fetch card after
    api_post "/cards/$num/closure" > /dev/null
    local response
    response=$(api_get "/cards/$num")
    results+=("$(echo "$response" | jq '{number: .number, title: .title, closed: .closed}')")
  done

  local response_data
  if [[ ${#results[@]} -eq 1 ]]; then
    response_data="${results[0]}"
    local summary="Closed card #${card_numbers[0]}"
  else
    response_data=$(printf '%s\n' "${results[@]}" | jq -s '.')
    local summary="Closed ${#card_numbers[@]} cards"
  fi

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "reopen" "fizzy reopen ${card_numbers[0]}" "Reopen card")" \
    "$(breadcrumb "show" "fizzy show ${card_numbers[0]}" "View card")"
  )

  output "$response_data" "$summary" "$breadcrumbs" "_close_md"
}

_close_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  md_heading 2 "Card Closed"
  echo "*$summary*"
  echo

  # Check if single card or array
  local is_array
  is_array=$(echo "$data" | jq 'if type == "array" then "yes" else "no" end' -r)

  if [[ "$is_array" == "yes" ]]; then
    echo "| # | Title | Status |"
    echo "|---|-------|--------|"
    echo "$data" | jq -r '.[] | "| #\(.number) | \(.title // "-")[0:40] | Closed |"'
  else
    local number title
    number=$(echo "$data" | jq -r '.number')
    title=$(echo "$data" | jq -r '.title // "-"')
    md_kv "Card" "#$number" "Title" "$title" "Status" "Closed"
  fi

  echo
  md_breadcrumbs "$breadcrumbs"
}

_close_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy close",
      description: "Close card(s)",
      usage: "fizzy close <number> [numbers...]",
      examples: ["fizzy close 123", "fizzy close 123 124 125"]
    }'
  else
    cat <<'EOF'
## fizzy close

Close card(s).

### Usage

    fizzy close <number> [numbers...]

### Examples

    fizzy close 123           Close card #123
    fizzy close 123 124 125   Close multiple cards
EOF
  fi
}


# fizzy reopen <number>
# Reopen a closed card

cmd_reopen() {
  local show_help=false
  local card_numbers=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy reopen --help"
        ;;
      *)
        card_numbers+=("$1")
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _reopen_help
    return 0
  fi

  if [[ ${#card_numbers[@]} -eq 0 ]]; then
    die "Card number required" $EXIT_USAGE "Usage: fizzy reopen <number>"
  fi

  local results=()
  local num
  for num in "${card_numbers[@]}"; do
    # DELETE closure returns 204 No Content, so fetch card after
    api_delete "/cards/$num/closure" > /dev/null
    local response
    response=$(api_get "/cards/$num")
    results+=("$(echo "$response" | jq '{number: .number, title: .title, closed: .closed}')")
  done

  local response_data
  if [[ ${#results[@]} -eq 1 ]]; then
    response_data="${results[0]}"
    local summary="Reopened card #${card_numbers[0]}"
  else
    response_data=$(printf '%s\n' "${results[@]}" | jq -s '.')
    local summary="Reopened ${#card_numbers[@]} cards"
  fi

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "close" "fizzy close ${card_numbers[0]}" "Close card")" \
    "$(breadcrumb "show" "fizzy show ${card_numbers[0]}" "View card")" \
    "$(breadcrumb "triage" "fizzy triage ${card_numbers[0]} --to <column>" "Move to column")"
  )

  output "$response_data" "$summary" "$breadcrumbs" "_reopen_md"
}

_reopen_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  md_heading 2 "Card Reopened"
  echo "*$summary*"
  echo

  local is_array
  is_array=$(echo "$data" | jq 'if type == "array" then "yes" else "no" end' -r)

  if [[ "$is_array" == "yes" ]]; then
    echo "| # | Title | Status |"
    echo "|---|-------|--------|"
    echo "$data" | jq -r '.[] | "| #\(.number) | \(.title // "-")[0:40] | Active |"'
  else
    local number title
    number=$(echo "$data" | jq -r '.number')
    title=$(echo "$data" | jq -r '.title // "-"')
    md_kv "Card" "#$number" "Title" "$title" "Status" "Active"
  fi

  echo
  md_breadcrumbs "$breadcrumbs"
}

_reopen_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy reopen",
      description: "Reopen closed card(s)",
      usage: "fizzy reopen <number> [numbers...]",
      examples: ["fizzy reopen 123", "fizzy reopen 123 124"]
    }'
  else
    cat <<'EOF'
## fizzy reopen

Reopen closed card(s).

### Usage

    fizzy reopen <number> [numbers...]

### Examples

    fizzy reopen 123          Reopen card #123
    fizzy reopen 123 124      Reopen multiple cards
EOF
  fi
}


# fizzy triage <number> --to <column_id>
# Move card to a column

cmd_triage() {
  local card_number=""
  local column_id=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --to)
        if [[ -z "${2:-}" ]]; then
          die "--to requires a column ID" $EXIT_USAGE
        fi
        column_id="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy triage --help"
        ;;
      *)
        if [[ -z "$card_number" ]]; then
          card_number="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _triage_help
    return 0
  fi

  if [[ -z "$card_number" ]]; then
    die "Card number required" $EXIT_USAGE "Usage: fizzy triage <number> --to <column>"
  fi

  if [[ -z "$column_id" ]]; then
    # Try to get default column from config
    column_id=$(get_column_id 2>/dev/null || true)
    if [[ -z "$column_id" ]]; then
      die "--to column ID required" $EXIT_USAGE "Usage: fizzy triage <number> --to <column>"
    fi
  fi

  # Resolve column name to ID if needed
  # First, try to get board_id from config
  local board_id
  board_id=$(get_board_id 2>/dev/null || true)
  if [[ -n "$board_id" ]]; then
    local resolved_board
    if resolved_board=$(resolve_board_id "$board_id"); then
      board_id="$resolved_board"
    fi
  fi

  # If no board context, fetch the card to get its board
  if [[ -z "$board_id" ]]; then
    local card_data
    if card_data=$(api_get "/cards/$card_number" 2>/dev/null); then
      board_id=$(echo "$card_data" | jq -r '.board.id // empty')
    fi
  fi

  # If we have a board context, try to resolve column name
  if [[ -n "$board_id" ]]; then
    local resolved_column
    if resolved_column=$(resolve_column_id "$column_id" "$board_id"); then
      column_id="$resolved_column"
    else
      # Only fail if it looks like a name (not UUID)
      if [[ ! "$column_id" =~ ^[a-z0-9]{20,}$ ]]; then
        die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy columns --board $board_id"
      fi
    fi
  else
    # No board context and column looks like a name - warn user
    if [[ ! "$column_id" =~ ^[a-z0-9]{20,}$ ]]; then
      die "Cannot resolve column name without board context" $EXIT_USAGE \
        "Use column ID directly, or set board context: fizzy config set board_id <id>"
    fi
  fi

  local body
  body=$(jq -n --arg column_id "$column_id" '{column_id: $column_id}')

  # POST triage returns 204 No Content, so fetch card after
  api_post "/cards/$card_number/triage" "$body" > /dev/null
  local response
  response=$(api_get "/cards/$card_number")

  local column_name
  column_name=$(echo "$response" | jq -r '.column.name // "column"')
  local summary="Card #$card_number triaged to $column_name"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "untriage" "fizzy untriage $card_number" "Send back to triage")" \
    "$(breadcrumb "show" "fizzy show $card_number" "View card")" \
    "$(breadcrumb "close" "fizzy close $card_number" "Close card")"
  )

  output "$response" "$summary" "$breadcrumbs" "_triage_md"
}

_triage_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local number title column_name board_name
  number=$(echo "$data" | jq -r '.number')
  title=$(echo "$data" | jq -r '.title // .description[0:40]')
  column_name=$(echo "$data" | jq -r '.column.name // "Triage"')
  board_name=$(echo "$data" | jq -r '.board.name')

  md_heading 2 "Card Triaged"
  echo
  md_kv "Card" "#$number" \
        "Title" "$title" \
        "Board" "$board_name" \
        "Column" "$column_name"

  md_breadcrumbs "$breadcrumbs"
}

_triage_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy triage",
      description: "Move card to a column",
      usage: "fizzy triage <number> --to <column>",
      options: [{flag: "--to", description: "Column name or ID to triage to"}],
      examples: ["fizzy triage 123 --to \"In Progress\"", "fizzy triage 123 --to abc456"]
    }'
  else
    cat <<'EOF'
## fizzy triage

Move card to a column.

### Usage

    fizzy triage <number> --to <column>

### Options

    --to          Column name or ID to triage to (required)
    --help, -h    Show this help

### Examples

    fizzy triage 123 --to "In Progress"   Move by column name
    fizzy triage 123 --to abc456          Move by column ID
EOF
  fi
}


# fizzy untriage <number>
# Send card back to triage

cmd_untriage() {
  local card_number=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy untriage --help"
        ;;
      *)
        if [[ -z "$card_number" ]]; then
          card_number="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _untriage_help
    return 0
  fi

  if [[ -z "$card_number" ]]; then
    die "Card number required" $EXIT_USAGE "Usage: fizzy untriage <number>"
  fi

  # DELETE triage returns 204 No Content, so fetch card after
  api_delete "/cards/$card_number/triage" > /dev/null
  local response
  response=$(api_get "/cards/$card_number")

  local summary="Card #$card_number sent back to triage"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "triage" "fizzy triage $card_number --to <column_id>" "Move to column")" \
    "$(breadcrumb "show" "fizzy show $card_number" "View card")"
  )

  output "$response" "$summary" "$breadcrumbs" "_untriage_md"
}

_untriage_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local number title board_name
  number=$(echo "$data" | jq -r '.number')
  title=$(echo "$data" | jq -r '.title // .description[0:40]')
  board_name=$(echo "$data" | jq -r '.board.name')

  md_heading 2 "Card Untriaged"
  echo
  md_kv "Card" "#$number" \
        "Title" "$title" \
        "Board" "$board_name" \
        "Status" "Back in Triage"

  md_breadcrumbs "$breadcrumbs"
}

_untriage_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy untriage",
      description: "Send card back to triage",
      usage: "fizzy untriage <number>",
      examples: ["fizzy untriage 123"]
    }'
  else
    cat <<'EOF'
## fizzy untriage

Send card back to triage.

### Usage

    fizzy untriage <number>

### Examples

    fizzy untriage 123    Send card #123 back to triage
EOF
  fi
}


# fizzy postpone <number>
# Move card to "Not Now"

cmd_postpone() {
  local card_number=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy postpone --help"
        ;;
      *)
        if [[ -z "$card_number" ]]; then
          card_number="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _postpone_help
    return 0
  fi

  if [[ -z "$card_number" ]]; then
    die "Card number required" $EXIT_USAGE "Usage: fizzy postpone <number>"
  fi

  # POST not_now returns 204 No Content, so fetch card after
  api_post "/cards/$card_number/not_now" > /dev/null
  local response
  response=$(api_get "/cards/$card_number")

  local summary="Card #$card_number moved to Not Now"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "triage" "fizzy triage $card_number --to <column_id>" "Move to column")" \
    "$(breadcrumb "show" "fizzy show $card_number" "View card")"
  )

  output "$response" "$summary" "$breadcrumbs" "_postpone_md"
}

_postpone_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local number title board_name
  number=$(echo "$data" | jq -r '.number')
  title=$(echo "$data" | jq -r '.title // .description[0:40]')
  board_name=$(echo "$data" | jq -r '.board.name')

  md_heading 2 "Card Postponed"
  echo
  md_kv "Card" "#$number" \
        "Title" "$title" \
        "Board" "$board_name" \
        "Status" "Not Now"

  md_breadcrumbs "$breadcrumbs"
}

_postpone_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy postpone",
      description: "Move card to Not Now",
      usage: "fizzy postpone <number>",
      examples: ["fizzy postpone 123"]
    }'
  else
    cat <<'EOF'
## fizzy postpone

Move card to "Not Now".

### Usage

    fizzy postpone <number>

### Examples

    fizzy postpone 123    Move card #123 to Not Now
EOF
  fi
}


# fizzy comment "text" --on <number>
# Add comment to a card

cmd_comment_create() {
  local content=""
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
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy comment --help"
        ;;
      *)
        if [[ -z "$content" ]]; then
          content="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _comment_create_help
    return 0
  fi

  if [[ -z "$content" ]]; then
    die "Comment content required" $EXIT_USAGE "Usage: fizzy comment \"text\" --on <number>"
  fi

  if [[ -z "$card_number" ]]; then
    die "--on card number required" $EXIT_USAGE "Usage: fizzy comment \"text\" --on <number>"
  fi

  local body
  body=$(jq -n --arg body "$content" '{comment: {body: $body}}')

  local response
  response=$(api_post "/cards/$card_number/comments" "$body")

  local comment_id
  comment_id=$(echo "$response" | jq -r '.id')
  local summary="Comment added to card #$card_number"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy show $card_number" "View card")" \
    "$(breadcrumb "comments" "fizzy comments --on $card_number" "View all comments")" \
    "$(breadcrumb "react" "fizzy react \"👍\" --comment $comment_id" "Add reaction")"
  )

  output "$response" "$summary" "$breadcrumbs" "_comment_created_md"
}

_comment_created_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local comment_id creator_name created_at
  comment_id=$(echo "$data" | jq -r '.id')
  creator_name=$(echo "$data" | jq -r '.creator.name // "You"')
  created_at=$(echo "$data" | jq -r '.created_at | split("T")[0]')

  md_heading 2 "Comment Added"
  echo
  md_kv "ID" "$comment_id" \
        "Author" "$creator_name" \
        "Date" "$created_at"

  md_breadcrumbs "$breadcrumbs"
}

_comment_create_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy comment",
      description: "Add comment to a card",
      usage: "fizzy comment \"text\" --on <number>",
      options: [{flag: "--on", description: "Card number to comment on"}],
      examples: ["fizzy comment \"LGTM!\" --on 123"]
    }'
  else
    cat <<'EOF'
## fizzy comment

Add comment to a card.

### Usage

    fizzy comment "text" --on <number>

### Options

    --on          Card number to comment on (required)
    --help, -h    Show this help

### Examples

    fizzy comment "LGTM!" --on 123    Add comment to card #123
EOF
  fi
}


# fizzy assign <number> --to <user_id>
# Toggle assignment

cmd_assign() {
  local card_number=""
  local user_id=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --to)
        if [[ -z "${2:-}" ]]; then
          die "--to requires a user ID" $EXIT_USAGE
        fi
        user_id="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy assign --help"
        ;;
      *)
        if [[ -z "$card_number" ]]; then
          card_number="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _assign_help
    return 0
  fi

  if [[ -z "$card_number" ]]; then
    die "Card number required" $EXIT_USAGE "Usage: fizzy assign <number> --to <user>"
  fi

  if [[ -z "$user_id" ]]; then
    die "--to user ID required" $EXIT_USAGE "Usage: fizzy assign <number> --to <user>"
  fi

  # Resolve user name/email to ID
  local resolved_user
  if resolved_user=$(resolve_user_id "$user_id"); then
    user_id="$resolved_user"
  else
    die "$RESOLVE_ERROR" $EXIT_NOT_FOUND "Use: fizzy people"
  fi

  local body
  body=$(jq -n --arg assignee_id "$user_id" '{assignee_id: $assignee_id}')

  # POST assignments returns 204 No Content, so fetch card after
  api_post "/cards/$card_number/assignments" "$body" > /dev/null
  local response
  response=$(api_get "/cards/$card_number")

  local summary="Assignment toggled on card #$card_number"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy show $card_number" "View card")" \
    "$(breadcrumb "people" "fizzy people" "List users")"
  )

  output "$response" "$summary" "$breadcrumbs" "_assign_md"
}

_assign_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local number title
  number=$(echo "$data" | jq -r '.number')
  title=$(echo "$data" | jq -r '.title // .description[0:40]')

  md_heading 2 "Assignment Toggled"
  echo
  md_kv "Card" "#$number" \
        "Title" "$title"

  md_breadcrumbs "$breadcrumbs"
}

_assign_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy assign",
      description: "Toggle assignment on a card",
      usage: "fizzy assign <number> --to <user>",
      options: [{flag: "--to", description: "User name, email, or ID to toggle assignment"}],
      examples: ["fizzy assign 123 --to \"Jane Doe\"", "fizzy assign 123 --to jane@example.com"]
    }'
  else
    cat <<'EOF'
## fizzy assign

Toggle assignment on a card (adds if not assigned, removes if assigned).

### Usage

    fizzy assign <number> --to <user>

### Options

    --to          User name, email, or ID to toggle assignment (required)
    --help, -h    Show this help

### Examples

    fizzy assign 123 --to "Jane Doe"        Assign by name
    fizzy assign 123 --to jane@example.com  Assign by email
EOF
  fi
}


# fizzy tag <number> --with "name"
# Toggle tag on card

cmd_tag() {
  local card_number=""
  local tag_name=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --with)
        if [[ -z "${2:-}" ]]; then
          die "--with requires a tag name" $EXIT_USAGE
        fi
        tag_name="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy tag --help"
        ;;
      *)
        if [[ -z "$card_number" ]]; then
          card_number="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _tag_help
    return 0
  fi

  if [[ -z "$card_number" ]]; then
    die "Card number required" $EXIT_USAGE "Usage: fizzy tag <number> --with <tag>"
  fi

  if [[ -z "$tag_name" ]]; then
    die "--with tag name required" $EXIT_USAGE "Usage: fizzy tag <number> --with <tag>"
  fi

  # Strip leading # if present (users may type #bug or bug)
  tag_name="${tag_name#\#}"

  # API expects tag_title (the tag name), not tag_id
  local body
  body=$(jq -n --arg tag_title "$tag_name" '{tag_title: $tag_title}')

  # POST taggings returns 204 No Content, so fetch card after
  api_post "/cards/$card_number/taggings" "$body" > /dev/null
  local response
  response=$(api_get "/cards/$card_number")

  local summary="Tag toggled on card #$card_number"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy show $card_number" "View card")" \
    "$(breadcrumb "tags" "fizzy tags" "List tags")"
  )

  output "$response" "$summary" "$breadcrumbs" "_tag_md"
}

_tag_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local number title tags
  number=$(echo "$data" | jq -r '.number')
  title=$(echo "$data" | jq -r '.title // .description[0:40]')
  tags=$(echo "$data" | jq -r '.tags | join(", ")')

  md_heading 2 "Tag Toggled"
  echo
  md_kv "Card" "#$number" \
        "Title" "$title" \
        "Tags" "${tags:-None}"

  md_breadcrumbs "$breadcrumbs"
}

_tag_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy tag",
      description: "Toggle tag on a card",
      usage: "fizzy tag <number> --with <name>",
      options: [{flag: "--with", description: "Tag name to toggle"}],
      examples: ["fizzy tag 123 --with \"bug\"", "fizzy tag 123 --with \"feature\""]
    }'
  else
    cat <<'EOF'
## fizzy tag

Toggle tag on a card (adds if not tagged, removes if tagged).

### Usage

    fizzy tag <number> --with <name>

### Options

    --with        Tag name to toggle (required)
    --help, -h    Show this help

### Examples

    fizzy tag 123 --with "bug"       Toggle "bug" tag
    fizzy tag 123 --with "feature"   Toggle "feature" tag
EOF
  fi
}


# fizzy watch <number>
# Subscribe to card notifications

cmd_watch() {
  local card_number=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy watch --help"
        ;;
      *)
        if [[ -z "$card_number" ]]; then
          card_number="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _watch_help
    return 0
  fi

  if [[ -z "$card_number" ]]; then
    die "Card number required" $EXIT_USAGE "Usage: fizzy watch <number>"
  fi

  # POST watch returns 204 No Content, so fetch card after
  api_post "/cards/$card_number/watch" > /dev/null
  local response
  response=$(api_get "/cards/$card_number")

  local summary="Subscribed to card #$card_number"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "unwatch" "fizzy unwatch $card_number" "Unsubscribe")" \
    "$(breadcrumb "show" "fizzy show $card_number" "View card")"
  )

  output "$response" "$summary" "$breadcrumbs" "_watch_md"
}

_watch_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local number title
  number=$(echo "$data" | jq -r '.number')
  title=$(echo "$data" | jq -r '.title // .description[0:40]')

  md_heading 2 "Subscribed"
  echo
  md_kv "Card" "#$number" \
        "Title" "$title" \
        "Watching" "Yes"

  md_breadcrumbs "$breadcrumbs"
}

_watch_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy watch",
      description: "Subscribe to card notifications",
      usage: "fizzy watch <number>",
      examples: ["fizzy watch 123"]
    }'
  else
    cat <<'EOF'
## fizzy watch

Subscribe to card notifications.

### Usage

    fizzy watch <number>

### Examples

    fizzy watch 123    Subscribe to card #123
EOF
  fi
}


# fizzy unwatch <number>
# Unsubscribe from card

cmd_unwatch() {
  local card_number=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy unwatch --help"
        ;;
      *)
        if [[ -z "$card_number" ]]; then
          card_number="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _unwatch_help
    return 0
  fi

  if [[ -z "$card_number" ]]; then
    die "Card number required" $EXIT_USAGE "Usage: fizzy unwatch <number>"
  fi

  # DELETE watch returns 204 No Content, so fetch card after
  api_delete "/cards/$card_number/watch" > /dev/null
  local response
  response=$(api_get "/cards/$card_number")

  local summary="Unsubscribed from card #$card_number"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "watch" "fizzy watch $card_number" "Subscribe")" \
    "$(breadcrumb "show" "fizzy show $card_number" "View card")"
  )

  output "$response" "$summary" "$breadcrumbs" "_unwatch_md"
}

_unwatch_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local number title
  number=$(echo "$data" | jq -r '.number')
  title=$(echo "$data" | jq -r '.title // .description[0:40]')

  md_heading 2 "Unsubscribed"
  echo
  md_kv "Card" "#$number" \
        "Title" "$title" \
        "Watching" "No"

  md_breadcrumbs "$breadcrumbs"
}

_unwatch_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy unwatch",
      description: "Unsubscribe from card notifications",
      usage: "fizzy unwatch <number>",
      examples: ["fizzy unwatch 123"]
    }'
  else
    cat <<'EOF'
## fizzy unwatch

Unsubscribe from card notifications.

### Usage

    fizzy unwatch <number>

### Examples

    fizzy unwatch 123    Unsubscribe from card #123
EOF
  fi
}


# fizzy gild <number>
# Mark card as golden

cmd_gild() {
  local card_number=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy gild --help"
        ;;
      *)
        if [[ -z "$card_number" ]]; then
          card_number="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _gild_help
    return 0
  fi

  if [[ -z "$card_number" ]]; then
    die "Card number required" $EXIT_USAGE "Usage: fizzy gild <number>"
  fi

  # POST goldness returns 204 No Content, so fetch card after
  api_post "/cards/$card_number/goldness" > /dev/null
  local response
  response=$(api_get "/cards/$card_number")

  local summary="Card #$card_number marked as golden"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "ungild" "fizzy ungild $card_number" "Remove golden")" \
    "$(breadcrumb "show" "fizzy show $card_number" "View card")"
  )

  output "$response" "$summary" "$breadcrumbs" "_gild_md"
}

_gild_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local number title
  number=$(echo "$data" | jq -r '.number')
  title=$(echo "$data" | jq -r '.title // .description[0:40]')

  md_heading 2 "Card Gilded"
  echo
  md_kv "Card" "#$number" \
        "Title" "$title" \
        "Golden" "Yes ✨"

  md_breadcrumbs "$breadcrumbs"
}

_gild_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy gild",
      description: "Mark card as golden",
      usage: "fizzy gild <number>",
      examples: ["fizzy gild 123"]
    }'
  else
    cat <<'EOF'
## fizzy gild

Mark card as golden (protects from auto-postponement).

### Usage

    fizzy gild <number>

### Examples

    fizzy gild 123    Mark card #123 as golden
EOF
  fi
}


# fizzy ungild <number>
# Remove golden status

cmd_ungild() {
  local card_number=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy ungild --help"
        ;;
      *)
        if [[ -z "$card_number" ]]; then
          card_number="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _ungild_help
    return 0
  fi

  if [[ -z "$card_number" ]]; then
    die "Card number required" $EXIT_USAGE "Usage: fizzy ungild <number>"
  fi

  # DELETE goldness returns 204 No Content, so fetch card after
  api_delete "/cards/$card_number/goldness" > /dev/null
  local response
  response=$(api_get "/cards/$card_number")

  local summary="Golden status removed from card #$card_number"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "gild" "fizzy gild $card_number" "Mark as golden")" \
    "$(breadcrumb "show" "fizzy show $card_number" "View card")"
  )

  output "$response" "$summary" "$breadcrumbs" "_ungild_md"
}

_ungild_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local number title
  number=$(echo "$data" | jq -r '.number')
  title=$(echo "$data" | jq -r '.title // .description[0:40]')

  md_heading 2 "Card Ungilded"
  echo
  md_kv "Card" "#$number" \
        "Title" "$title" \
        "Golden" "No"

  md_breadcrumbs "$breadcrumbs"
}

_ungild_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy ungild",
      description: "Remove golden status from card",
      usage: "fizzy ungild <number>",
      examples: ["fizzy ungild 123"]
    }'
  else
    cat <<'EOF'
## fizzy ungild

Remove golden status from card.

### Usage

    fizzy ungild <number>

### Examples

    fizzy ungild 123    Remove golden from card #123
EOF
  fi
}


# fizzy step "text" --on <number>
# Add step to card

cmd_step() {
  local content=""
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
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy step --help"
        ;;
      *)
        if [[ -z "$content" ]]; then
          content="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _step_help
    return 0
  fi

  if [[ -z "$content" ]]; then
    die "Step content required" $EXIT_USAGE "Usage: fizzy step \"text\" --on <number>"
  fi

  if [[ -z "$card_number" ]]; then
    die "--on card number required" $EXIT_USAGE "Usage: fizzy step \"text\" --on <number>"
  fi

  local body
  body=$(jq -n --arg content "$content" '{content: $content}')

  local response
  response=$(api_post "/cards/$card_number/steps" "$body")

  local summary="Step added to card #$card_number"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "show" "fizzy show $card_number" "View card")" \
    "$(breadcrumb "step" "fizzy step \"text\" --on $card_number" "Add another step")"
  )

  output "$response" "$summary" "$breadcrumbs" "_step_md"
}

_step_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local step_id content completed
  step_id=$(echo "$data" | jq -r '.id')
  content=$(echo "$data" | jq -r '.content')
  completed=$(echo "$data" | jq -r 'if .completed then "Yes" else "No" end')

  md_heading 2 "Step Added"
  echo
  md_kv "ID" "$step_id" \
        "Content" "$content" \
        "Completed" "$completed"

  md_breadcrumbs "$breadcrumbs"
}

_step_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy step",
      description: "Add step to a card",
      usage: "fizzy step \"text\" --on <number>",
      options: [{flag: "--on", description: "Card number to add step to"}],
      examples: ["fizzy step \"Review PR\" --on 123"]
    }'
  else
    cat <<'EOF'
## fizzy step

Add step (checklist item) to a card.

### Usage

    fizzy step "text" --on <number>

### Options

    --on          Card number to add step to (required)
    --help, -h    Show this help

### Examples

    fizzy step "Review PR" --on 123    Add step to card #123
EOF
  fi
}


# fizzy react "emoji" --comment <comment_id> --card <card_number>
# Add reaction to comment

cmd_react() {
  local emoji=""
  local comment_id=""
  local card_number=""
  local show_help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --comment)
        if [[ -z "${2:-}" ]]; then
          die "--comment requires a comment ID" $EXIT_USAGE
        fi
        comment_id="$2"
        shift 2
        ;;
      --card)
        if [[ -z "${2:-}" ]]; then
          die "--card requires a card number" $EXIT_USAGE
        fi
        card_number="$2"
        shift 2
        ;;
      --help|-h)
        show_help=true
        shift
        ;;
      -*)
        die "Unknown option: $1" $EXIT_USAGE "Run: fizzy react --help"
        ;;
      *)
        if [[ -z "$emoji" ]]; then
          emoji="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$show_help" == "true" ]]; then
    _react_help
    return 0
  fi

  if [[ -z "$emoji" ]]; then
    die "Emoji required" $EXIT_USAGE "Usage: fizzy react \"👍\" --card <num> --comment <id>"
  fi

  if [[ -z "$card_number" ]]; then
    die "--card number required" $EXIT_USAGE "Usage: fizzy react \"👍\" --card <num> --comment <id>"
  fi

  if [[ -z "$comment_id" ]]; then
    die "--comment ID required" $EXIT_USAGE "Usage: fizzy react \"👍\" --card <num> --comment <id>"
  fi

  local body
  body=$(jq -n --arg content "$emoji" '{reaction: {content: $content}}')

  # POST reactions returns 201 with no body/Location, construct response
  api_post "/cards/$card_number/comments/$comment_id/reactions" "$body" > /dev/null
  local response
  response=$(jq -n --arg emoji "$emoji" --arg card_number "$card_number" --arg comment_id "$comment_id" \
    '{emoji: $emoji, card_number: $card_number, comment_id: $comment_id}')

  local summary="Reaction added to comment"

  local breadcrumbs
  breadcrumbs=$(breadcrumbs \
    "$(breadcrumb "comments" "fizzy comments --on $card_number" "View comments")" \
    "$(breadcrumb "show" "fizzy show $card_number" "View card")"
  )

  output "$response" "$summary" "$breadcrumbs" "_react_md"
}

_react_md() {
  local data="$1"
  local summary="$2"
  local breadcrumbs="$3"

  local emoji card_number comment_id
  emoji=$(echo "$data" | jq -r '.emoji')
  card_number=$(echo "$data" | jq -r '.card_number')
  comment_id=$(echo "$data" | jq -r '.comment_id')

  md_heading 2 "Reaction Added"
  echo
  md_kv "Emoji" "$emoji" \
        "Card" "#$card_number" \
        "Comment" "$comment_id"

  md_breadcrumbs "$breadcrumbs"
}

_react_help() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy react",
      description: "Add reaction to a comment",
      usage: "fizzy react \"emoji\" --card <number> --comment <id>",
      options: [
        {flag: "--card", description: "Card number"},
        {flag: "--comment", description: "Comment ID to react to"}
      ],
      examples: ["fizzy react \"👍\" --card 123 --comment abc456"]
    }'
  else
    cat <<'EOF'
## fizzy react

Add reaction to a comment.

### Usage

    fizzy react "emoji" --card <number> --comment <id>

### Options

    --card        Card number (required)
    --comment     Comment ID to react to (required)
    --help, -h    Show this help

### Examples

    fizzy react "👍" --card 123 --comment abc456
EOF
  fi
}
