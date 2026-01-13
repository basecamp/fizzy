#!/usr/bin/env bash
# names.sh - Name resolution for fizzy
#
# Allows using human-readable names instead of IDs for boards and users.
# Uses a session cache to avoid repeated API calls.


# Cache directory (session-scoped temp files)
_FIZZY_CACHE_DIR="${TMPDIR:-/tmp}/fizzy-cache-$$"

# Global error message for resolution failures
# Initialized here so it's always declared (resolver functions run in subshells
# via command substitution, so their assignments don't reach the parent shell)
RESOLVE_ERROR=""


# Cache Management

_ensure_cache_dir() {
  if [[ ! -d "$_FIZZY_CACHE_DIR" ]]; then
    mkdir -p "$_FIZZY_CACHE_DIR"
  fi
}

_get_cache() {
  local type="$1"
  local file="$_FIZZY_CACHE_DIR/${type}.json"
  if [[ -f "$file" ]]; then
    cat "$file"
  fi
}

_set_cache() {
  local type="$1"
  local data="$2"
  _ensure_cache_dir
  echo "$data" > "$_FIZZY_CACHE_DIR/${type}.json"
}

_clear_cache() {
  rm -rf "$_FIZZY_CACHE_DIR"
}


# Board Resolution

# Resolve a board name or ID to an ID
# Args: $1 - board name, partial name, or ID
# Returns: board ID (or empty if not found)
# Sets: RESOLVE_ERROR with error message if ambiguous/not found
resolve_board_id() {
  local input="$1"
  RESOLVE_ERROR=""

  # If it looks like a UUID (25+ chars, alphanumeric), assume it's an ID
  if [[ "$input" =~ ^[a-z0-9]{20,}$ ]]; then
    echo "$input"
    return 0
  fi

  # Fetch boards (with cache)
  local boards
  boards=$(_get_cache "boards")
  if [[ -z "$boards" ]]; then
    # Don't suppress stderr - let auth errors propagate and exit
    boards=$(api_get "/boards") || return 1
    _set_cache "boards" "$boards"
  fi

  # Try exact match first
  local exact_match
  exact_match=$(echo "$boards" | jq -r --arg name "$input" \
    '.[] | select(.name == $name) | .id' | head -1)
  if [[ -n "$exact_match" ]]; then
    echo "$exact_match"
    return 0
  fi

  # Try case-insensitive match
  local ci_matches
  ci_matches=$(echo "$boards" | jq -r --arg name "$input" \
    '.[] | select(.name | ascii_downcase == ($name | ascii_downcase)) | .id')
  local ci_count
  ci_count=0
  [[ -n "$ci_matches" ]] && ci_count=$(echo "$ci_matches" | grep -c . || true)
  if [[ "$ci_count" -eq 1 ]]; then
    echo "$ci_matches"
    return 0
  fi

  # Try partial match (contains)
  local partial_matches
  partial_matches=$(echo "$boards" | jq -r --arg name "$input" \
    '.[] | select(.name | ascii_downcase | contains($name | ascii_downcase)) | "\(.id):\(.name)"')
  local partial_count
  partial_count=0
  [[ -n "$partial_matches" ]] && partial_count=$(echo "$partial_matches" | grep -c . || true)

  if [[ "$partial_count" -eq 1 ]]; then
    echo "$partial_matches" | cut -d: -f1
    return 0
  elif [[ "$partial_count" -gt 1 ]]; then
    local names
    names=$(echo "$partial_matches" | cut -d: -f2- | tr '\n' ',' | sed 's/,$//')
    RESOLVE_ERROR="Ambiguous board name '$input' matches: $names"
    return 1
  fi

  # Not found - provide suggestions
  RESOLVE_ERROR="Board not found: $input"
  local suggestions
  suggestions=$(_suggest_similar "$input" "$boards" "name")
  if [[ -n "$suggestions" ]]; then
    RESOLVE_ERROR="$RESOLVE_ERROR. Did you mean: $suggestions?"
  fi
  return 1
}

# Get cached boards list (for suggestions)
get_boards_list() {
  local boards
  boards=$(_get_cache "boards")
  if [[ -z "$boards" ]]; then
    boards=$(api_get "/boards") || return 1
    _set_cache "boards" "$boards"
  fi
  echo "$boards"
}


# User Resolution

# Resolve a user name, email, or ID to an ID
# Args: $1 - user name, email, partial name, or ID
# Returns: user ID (or empty if not found)
# Sets: RESOLVE_ERROR with error message if ambiguous/not found
resolve_user_id() {
  local input="$1"
  RESOLVE_ERROR=""

  # If it looks like a UUID (25+ chars, alphanumeric), assume it's an ID
  if [[ "$input" =~ ^[a-z0-9]{20,}$ ]]; then
    echo "$input"
    return 0
  fi

  # Fetch users (with cache)
  local users
  users=$(_get_cache "users")
  if [[ -z "$users" ]]; then
    # Don't suppress stderr - let auth errors propagate and exit
    users=$(api_get "/users") || return 1
    _set_cache "users" "$users"
  fi

  # Try exact email match first
  if [[ "$input" == *@* ]]; then
    local email_match
    email_match=$(echo "$users" | jq -r --arg email "$input" \
      '.[] | select(.email_address == $email) | .id' | head -1)
    if [[ -n "$email_match" ]]; then
      echo "$email_match"
      return 0
    fi
  fi

  # Try exact name match
  local exact_match
  exact_match=$(echo "$users" | jq -r --arg name "$input" \
    '.[] | select(.name == $name) | .id' | head -1)
  if [[ -n "$exact_match" ]]; then
    echo "$exact_match"
    return 0
  fi

  # Try case-insensitive name match
  local ci_matches
  ci_matches=$(echo "$users" | jq -r --arg name "$input" \
    '.[] | select(.name | ascii_downcase == ($name | ascii_downcase)) | .id')
  local ci_count
  ci_count=0
  [[ -n "$ci_matches" ]] && ci_count=$(echo "$ci_matches" | grep -c . || true)
  if [[ "$ci_count" -eq 1 ]]; then
    echo "$ci_matches"
    return 0
  fi

  # Try partial name match (contains)
  local partial_matches
  partial_matches=$(echo "$users" | jq -r --arg name "$input" \
    '.[] | select(.name | ascii_downcase | contains($name | ascii_downcase)) | "\(.id):\(.name)"')
  local partial_count
  partial_count=0
  [[ -n "$partial_matches" ]] && partial_count=$(echo "$partial_matches" | grep -c . || true)

  if [[ "$partial_count" -eq 1 ]]; then
    echo "$partial_matches" | cut -d: -f1
    return 0
  elif [[ "$partial_count" -gt 1 ]]; then
    local names
    names=$(echo "$partial_matches" | cut -d: -f2- | tr '\n' ',' | sed 's/,$//')
    RESOLVE_ERROR="Ambiguous user name '$input' matches: $names"
    return 1
  fi

  # Not found - provide suggestions
  RESOLVE_ERROR="User not found: $input"
  local suggestions
  suggestions=$(_suggest_similar "$input" "$users" "name")
  if [[ -n "$suggestions" ]]; then
    RESOLVE_ERROR="$RESOLVE_ERROR. Did you mean: $suggestions?"
  fi
  return 1
}

# Get cached users list (for suggestions)
get_users_list() {
  local users
  users=$(_get_cache "users")
  if [[ -z "$users" ]]; then
    users=$(api_get "/users") || return 1
    _set_cache "users" "$users"
  fi
  echo "$users"
}


# Column Resolution

# Resolve a column name or ID to an ID (within a board)
# Args: $1 - column name, partial name, or ID
#       $2 - board ID (required)
# Returns: column ID (or empty if not found)
# Sets: RESOLVE_ERROR with error message if ambiguous/not found
resolve_column_id() {
  local input="$1"
  local board_id="$2"
  RESOLVE_ERROR=""

  if [[ -z "$board_id" ]]; then
    RESOLVE_ERROR="Board ID required for column resolution"
    return 1
  fi

  # If it looks like a UUID (25+ chars, alphanumeric), assume it's an ID
  if [[ "$input" =~ ^[a-z0-9]{20,}$ ]]; then
    echo "$input"
    return 0
  fi

  # Fetch columns (with cache per board)
  local cache_key="columns_${board_id}"
  local columns
  columns=$(_get_cache "$cache_key")
  if [[ -z "$columns" ]]; then
    # Don't suppress stderr - let auth errors propagate and exit
    columns=$(api_get "/boards/$board_id/columns") || return 1
    _set_cache "$cache_key" "$columns"
  fi

  # Try exact match first
  local exact_match
  exact_match=$(echo "$columns" | jq -r --arg name "$input" \
    '.[] | select(.name == $name) | .id' | head -1)
  if [[ -n "$exact_match" ]]; then
    echo "$exact_match"
    return 0
  fi

  # Try case-insensitive match
  local ci_matches
  ci_matches=$(echo "$columns" | jq -r --arg name "$input" \
    '.[] | select(.name | ascii_downcase == ($name | ascii_downcase)) | .id')
  local ci_count=0
  [[ -n "$ci_matches" ]] && ci_count=$(echo "$ci_matches" | grep -c . || true)
  if [[ "$ci_count" -eq 1 ]]; then
    echo "$ci_matches"
    return 0
  fi

  # Try partial match (contains)
  local partial_matches
  partial_matches=$(echo "$columns" | jq -r --arg name "$input" \
    '.[] | select(.name | ascii_downcase | contains($name | ascii_downcase)) | "\(.id):\(.name)"')
  local partial_count=0
  [[ -n "$partial_matches" ]] && partial_count=$(echo "$partial_matches" | grep -c . || true)

  if [[ "$partial_count" -eq 1 ]]; then
    echo "$partial_matches" | cut -d: -f1
    return 0
  elif [[ "$partial_count" -gt 1 ]]; then
    local names
    names=$(echo "$partial_matches" | cut -d: -f2- | tr '\n' ',' | sed 's/,$//')
    RESOLVE_ERROR="Ambiguous column name '$input' matches: $names"
    return 1
  fi

  # Not found - provide suggestions
  RESOLVE_ERROR="Column not found: $input"
  local suggestions
  suggestions=$(_suggest_similar "$input" "$columns" "name")
  if [[ -n "$suggestions" ]]; then
    RESOLVE_ERROR="$RESOLVE_ERROR. Did you mean: $suggestions?"
  fi
  return 1
}


# Tag Resolution

# Resolve a tag name or ID to an ID
# Args: $1 - tag name, partial name, or ID
# Returns: tag ID (or empty if not found)
# Sets: RESOLVE_ERROR with error message if ambiguous/not found
resolve_tag_id() {
  local input="$1"
  RESOLVE_ERROR=""

  # If it looks like a UUID (25+ chars, alphanumeric), assume it's an ID
  if [[ "$input" =~ ^[a-z0-9]{20,}$ ]]; then
    echo "$input"
    return 0
  fi

  # Fetch tags (with cache)
  local tags
  tags=$(_get_cache "tags")
  if [[ -z "$tags" ]]; then
    # Don't suppress stderr - let auth errors propagate and exit
    tags=$(api_get "/tags") || return 1
    _set_cache "tags" "$tags"
  fi

  # Try exact match first
  local exact_match
  exact_match=$(echo "$tags" | jq -r --arg name "$input" \
    '.[] | select(.name == $name) | .id' | head -1)
  if [[ -n "$exact_match" ]]; then
    echo "$exact_match"
    return 0
  fi

  # Try case-insensitive match
  local ci_matches
  ci_matches=$(echo "$tags" | jq -r --arg name "$input" \
    '.[] | select(.name | ascii_downcase == ($name | ascii_downcase)) | .id')
  local ci_count
  ci_count=0
  [[ -n "$ci_matches" ]] && ci_count=$(echo "$ci_matches" | grep -c . || true)
  if [[ "$ci_count" -eq 1 ]]; then
    echo "$ci_matches"
    return 0
  fi

  # Try partial match (contains)
  local partial_matches
  partial_matches=$(echo "$tags" | jq -r --arg name "$input" \
    '.[] | select(.name | ascii_downcase | contains($name | ascii_downcase)) | "\(.id):\(.name)"')
  local partial_count
  partial_count=0
  [[ -n "$partial_matches" ]] && partial_count=$(echo "$partial_matches" | grep -c . || true)

  if [[ "$partial_count" -eq 1 ]]; then
    echo "$partial_matches" | cut -d: -f1
    return 0
  elif [[ "$partial_count" -gt 1 ]]; then
    local names
    names=$(echo "$partial_matches" | cut -d: -f2- | tr '\n' ',' | sed 's/,$//')
    RESOLVE_ERROR="Ambiguous tag name '$input' matches: $names"
    return 1
  fi

  # Not found - provide suggestions
  RESOLVE_ERROR="Tag not found: $input"
  local suggestions
  suggestions=$(_suggest_similar "$input" "$tags" "name")
  if [[ -n "$suggestions" ]]; then
    RESOLVE_ERROR="$RESOLVE_ERROR. Did you mean: $suggestions?"
  fi
  return 1
}


# Suggestion Helpers

# Suggest similar names using simple substring/distance matching
# Args: $1 - input string
#       $2 - JSON array of objects
#       $3 - field name to match against
# Returns: comma-separated list of similar names (up to 3)
_suggest_similar() {
  local input="$1"
  local json_array="$2"
  local field="$3"

  # Get all names
  local names
  names=$(echo "$json_array" | jq -r ".[].$field")

  # Find names that share a common prefix (first 3 chars)
  local prefix="${input:0:3}"
  local suggestions
  suggestions=$(echo "$names" | grep -i "^$prefix" | head -3 | tr '\n' ',' | sed 's/,$//')

  # If no prefix matches, try substring matches
  if [[ -z "$suggestions" ]]; then
    suggestions=$(echo "$names" | grep -i "$input" | head -3 | tr '\n' ',' | sed 's/,$//')
  fi

  # If still nothing, return first few available options
  if [[ -z "$suggestions" ]]; then
    suggestions=$(echo "$names" | head -3 | tr '\n' ',' | sed 's/,$//')
  fi

  echo "$suggestions"
}


# Error Message Formatting

# Format resolution error for die() with hint
# Args: $1 - entity type (board, user, column, tag)
#       $2 - the failed input
# Uses: RESOLVE_ERROR
format_resolve_error() {
  local type="$1"
  local input="$2"

  if [[ -n "$RESOLVE_ERROR" ]]; then
    echo "$RESOLVE_ERROR"
  else
    echo "${type^} not found: $input"
  fi
}
