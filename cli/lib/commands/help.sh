#!/usr/bin/env bash
# help.sh - Help and quick-start commands


cmd_help() {
  local topic="${1:-}"
  local format
  format=$(get_format)

  if [[ -n "$topic" ]]; then
    _help_topic "$topic"
    return
  fi

  if [[ "$format" == "json" ]]; then
    _help_json
  else
    _help_md
  fi
}

cmd_quick_start() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    _quick_start_json
  else
    _quick_start_md
  fi
}

_help_topic() {
  local topic="$1"
  local format
  format=$(get_format)

  case "$topic" in
    auth) _help_auth ;;
    config) _help_config ;;
    cards) _help_cards ;;
    boards) _help_boards ;;
    *)
      if [[ "$format" == "json" ]]; then
        json_error "Unknown help topic: $topic" "not_found"
      else
        echo "Unknown help topic: $topic"
        echo
        echo "Available topics: auth, config, cards, boards"
      fi
      exit 1
      ;;
  esac
}

_help_json() {
  jq -n \
    --arg version "$FIZZY_VERSION" \
    '{
      name: "fizzy",
      version: $version,
      description: "Agent-first CLI for Fizzy",
      commands: {
        query: ["boards", "cards", "columns", "comments", "notifications", "people", "search", "show", "tags"],
        actions: ["card", "close", "reopen", "triage", "untriage", "postpone", "comment", "assign", "tag", "watch", "unwatch", "gild", "ungild", "step", "react"],
        meta: ["auth", "config", "version", "help"]
      },
      global_flags: [
        {"flag": "--json/-j", "description": "Force JSON output"},
        {"flag": "--md/-m", "description": "Force markdown output"},
        {"flag": "--quiet/-q", "description": "Suppress non-essential output"},
        {"flag": "--verbose/-v", "description": "Debug output"},
        {"flag": "--board/-b", "description": "Board ID or name"},
        {"flag": "--account/-a", "description": "Account slug"}
      ]
    }'
}

_help_md() {
  cat <<'EOF'
# fizzy

Agent-first CLI for Fizzy.

## USAGE

    fizzy [global-flags] <command> [command-flags] [arguments]

## GLOBAL FLAGS

    --json, -j       Force JSON output
    --md, -m         Force markdown output
    --quiet, -q      Suppress non-essential output (data only)
    --verbose, -v    Debug output
    --board, -b      Board ID or name
    --account, -a    Account slug

## COMMANDS

### Query
    boards           List boards
    cards            List or filter cards
    columns          List columns on a board
    comments         List comments on a card
    notifications    List notifications
    people           List users in account
    search           Search cards
    show             Show card details
    tags             List tags

### Actions
    card             Create a new card
    close            Close a card
    reopen           Reopen a closed card
    triage           Move card into a column
    untriage         Send card back to triage
    postpone         Move card to "Not Now"
    comment          Add comment to a card
    assign           Assign/unassign user to card
    tag              Toggle tag on card
    watch            Subscribe to card notifications
    unwatch          Unsubscribe from card
    gild             Mark card as golden
    ungild           Remove golden status
    step             Manage card steps
    react            Add reaction to comment

### Meta
    auth             Authentication management
    config           Configuration management
    version          Show version
    help             Show this help

## EXAMPLES

    fizzy boards                  List all boards
    fizzy cards --board Fizzy     List cards on Fizzy board
    fizzy show 42                 Show card #42
    fizzy card "New feature"      Create a new card
    fizzy close 42                Close card #42
    fizzy comment 42 "LGTM"       Comment on card #42

## CONFIGURATION

    fizzy config list             Show current configuration
    fizzy config set key value    Set a config value
    fizzy config get key          Get a config value

Run `fizzy help <command>` for command-specific help.
EOF
}

_quick_start_json() {
  local auth_status="unauthenticated"
  local account_slug=""
  local board_id=""

  if get_access_token &>/dev/null; then
    auth_status="authenticated"
    account_slug=$(get_account_slug 2>/dev/null || true)
    board_id=$(get_board_id 2>/dev/null || true)
  fi

  jq -n \
    --arg version "$FIZZY_VERSION" \
    --arg auth "$auth_status" \
    --arg account "$account_slug" \
    --arg board "$board_id" \
    '{
      version: $version,
      auth: $auth,
      context: {
        account: (if $account != "" then $account else null end),
        board: (if $board != "" then $board else null end)
      },
      next_steps: (
        if $auth == "unauthenticated" then
          ["Run: fizzy auth login"]
        elif $account == "" then
          ["Run: fizzy config set account_slug <slug>"]
        else
          ["fizzy boards", "fizzy cards", "fizzy help"]
        end
      )
    }'
}

_quick_start_md() {
  echo "# fizzy $FIZZY_VERSION"
  echo

  if ! get_access_token &>/dev/null; then
    echo "## Getting Started"
    echo
    echo "Not authenticated. Run:"
    echo
    echo "    fizzy auth login"
    echo
    return
  fi

  local account_slug
  account_slug=$(get_account_slug 2>/dev/null || true)

  if [[ -z "$account_slug" ]]; then
    echo "## Setup Required"
    echo
    echo "Authenticated but no account configured."
    echo
    echo "    fizzy config set account_slug <slug>"
    echo
    return
  fi

  echo "## Ready"
  echo
  echo "Account: $account_slug"

  local board_id
  board_id=$(get_board_id 2>/dev/null || true)
  if [[ -n "$board_id" ]]; then
    echo "Board: $board_id"
  fi
  echo

  echo "### Quick Commands"
  echo
  echo "    fizzy boards          List boards"
  echo "    fizzy cards           List cards"
  echo "    fizzy show <number>   Show card details"
  echo "    fizzy help            Full command list"
  echo
}


_help_config() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy config",
      description: "Manage configuration",
      subcommands: [
        {name: "list", description: "Show current configuration"},
        {name: "get", args: ["key"], description: "Get a config value"},
        {name: "set", args: ["key", "value"], description: "Set a config value"},
        {name: "unset", args: ["key"], description: "Remove a config value"}
      ],
      options: [
        {flag: "--global", description: "Use global (user) config"},
        {flag: "--local", description: "Use local (.fizzy/) config"}
      ],
      config_keys: [
        "account_slug",
        "board_id",
        "column_id",
        "base_url"
      ]
    }'
  else
    cat <<'EOF'
## fizzy config

Manage configuration.

### Subcommands

- `list`  - Show current configuration
- `get`   - Get a config value
- `set`   - Set a config value
- `unset` - Remove a config value

### Options

- `--global` - Use global (user) config
- `--local`  - Use local (.fizzy/) config

### Config Keys

- `account_slug` - Fizzy account slug
- `board_id`     - Default board ID
- `column_id`    - Default column ID
- `base_url`     - Fizzy server URL

### Examples

```bash
# Show current config
fizzy config list

# Set account globally
fizzy config set --global account_slug 897362094

# Set board for this project
fizzy config set board_id abc123
```
EOF
  fi
}

_help_cards() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy cards",
      description: "List and filter cards",
      options: [
        {flag: "--board", description: "Filter by board ID or name"},
        {flag: "--search", description: "Search terms"},
        {flag: "--tag", description: "Filter by tag"},
        {flag: "--assignee", description: "Filter by assignee"},
        {flag: "--status", description: "Filter by status (all, closed, not_now, golden)"}
      ]
    }'
  else
    cat <<'EOF'
## fizzy cards

List and filter cards.

### Options

- `--board`    - Filter by board ID or name
- `--search`   - Search terms
- `--tag`      - Filter by tag
- `--assignee` - Filter by assignee
- `--status`   - Filter by status (all, closed, not_now, golden)

### Examples

```bash
# List all cards
fizzy cards

# Search cards
fizzy cards --search "bug fix"

# Filter by board
fizzy cards --board Fizzy
```
EOF
  fi
}

_help_boards() {
  local format
  format=$(get_format)

  if [[ "$format" == "json" ]]; then
    jq -n '{
      command: "fizzy boards",
      description: "List boards in the account"
    }'
  else
    cat <<'EOF'
## fizzy boards

List boards in the account.

### Examples

```bash
# List all boards
fizzy boards
```
EOF
  fi
}
