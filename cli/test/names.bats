#!/usr/bin/env bats
# names.bats - Tests for name resolution (Phase 4)

load test_helper


# resolve_board_id tests

@test "resolve_board_id returns ID unchanged for UUID-like input" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/api.sh"
  source "$FIZZY_ROOT/lib/names.sh"

  # UUID-like strings should pass through unchanged (25+ alphanumeric)
  result=$(resolve_board_id "abc123def456ghi789jkl012mno")
  [[ "$result" == "abc123def456ghi789jkl012mno" ]]
}

@test "resolve_user_id returns ID unchanged for UUID-like input" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/api.sh"
  source "$FIZZY_ROOT/lib/names.sh"

  result=$(resolve_user_id "abc123def456ghi789jkl012mno")
  [[ "$result" == "abc123def456ghi789jkl012mno" ]]
}

@test "resolve_column_id returns ID unchanged for UUID-like input" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/api.sh"
  source "$FIZZY_ROOT/lib/names.sh"

  result=$(resolve_column_id "abc123def456ghi789jkl012mno" "board123")
  [[ "$result" == "abc123def456ghi789jkl012mno" ]]
}

@test "resolve_tag_id returns ID unchanged for UUID-like input" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/api.sh"
  source "$FIZZY_ROOT/lib/names.sh"

  result=$(resolve_tag_id "abc123def456ghi789jkl012mno")
  [[ "$result" == "abc123def456ghi789jkl012mno" ]]
}


# resolve_column_id edge cases

@test "resolve_column_id requires board_id" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/api.sh"
  source "$FIZZY_ROOT/lib/names.sh"

  ! resolve_column_id "My Column" ""
  [[ "$RESOLVE_ERROR" == "Board ID required for column resolution" ]]
}


# Help text updated to show name support

@test "cards --help mentions name support" {
  run fizzy --md cards --help
  assert_success
  assert_output_contains "name or ID"
}

@test "columns --help mentions name support" {
  run fizzy --md columns --help
  assert_success
  assert_output_contains "name or ID"
}

@test "card --help mentions name support" {
  run fizzy --md card --help
  assert_success
  assert_output_contains "name or ID"
}

@test "triage --help mentions name support" {
  run fizzy --md triage --help
  assert_success
  assert_output_contains "name or ID"
}

@test "assign --help mentions name support" {
  run fizzy --md assign --help
  assert_success
  assert_output_contains "name"
}

@test "tag --help mentions name support" {
  run fizzy --md tag --help
  assert_success
  assert_output_contains "name or ID"
}


# Cache management

@test "_ensure_cache_dir creates cache directory" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/api.sh"
  source "$FIZZY_ROOT/lib/names.sh"

  # Set a test cache dir
  export _FIZZY_CACHE_DIR="$TEST_HOME/fizzy-cache-test"
  rm -rf "$_FIZZY_CACHE_DIR"

  _ensure_cache_dir
  [[ -d "$_FIZZY_CACHE_DIR" ]]
}

@test "_set_cache and _get_cache work" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/api.sh"
  source "$FIZZY_ROOT/lib/names.sh"

  export _FIZZY_CACHE_DIR="$TEST_HOME/fizzy-cache-test"
  rm -rf "$_FIZZY_CACHE_DIR"

  _set_cache "test" '{"id": "123", "name": "Test"}'
  result=$(_get_cache "test")
  [[ "$result" == '{"id": "123", "name": "Test"}' ]]
}

@test "_clear_cache removes cache directory" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/api.sh"
  source "$FIZZY_ROOT/lib/names.sh"

  export _FIZZY_CACHE_DIR="$TEST_HOME/fizzy-cache-test"
  rm -rf "$_FIZZY_CACHE_DIR"

  _ensure_cache_dir
  [[ -d "$_FIZZY_CACHE_DIR" ]]

  _clear_cache
  [[ ! -d "$_FIZZY_CACHE_DIR" ]]
}


# Suggestion helper

@test "_suggest_similar returns suggestions" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/api.sh"
  source "$FIZZY_ROOT/lib/names.sh"

  local json='[{"name": "Engineering"}, {"name": "Design"}, {"name": "Marketing"}]'
  result=$(_suggest_similar "Eng" "$json" "name")
  [[ "$result" == *"Engineering"* ]]
}

@test "_suggest_similar returns multiple suggestions" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/api.sh"
  source "$FIZZY_ROOT/lib/names.sh"

  local json='[{"name": "Dev Team"}, {"name": "Dev Ops"}, {"name": "Design"}]'
  result=$(_suggest_similar "Dev" "$json" "name")
  [[ "$result" == *"Dev Team"* ]]
  [[ "$result" == *"Dev Ops"* ]]
}


# Error message formatting

@test "format_resolve_error uses RESOLVE_ERROR" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/api.sh"
  source "$FIZZY_ROOT/lib/names.sh"

  RESOLVE_ERROR="Board not found: My Board"
  result=$(format_resolve_error "board" "My Board")
  [[ "$result" == "Board not found: My Board" ]]
}

@test "format_resolve_error provides default message" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/api.sh"
  source "$FIZZY_ROOT/lib/names.sh"

  RESOLVE_ERROR=""
  result=$(format_resolve_error "board" "My Board")
  [[ "$result" == "Board not found: My Board" ]]
}
