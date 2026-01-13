#!/usr/bin/env bats
# config.bats - Tests for lib/config.sh

load test_helper


# Config loading

@test "loads global config" {
  create_global_config '{"account_slug": "12345"}'

  # Source the lib directly to test
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config "account_slug")
  [[ "$result" == "12345" ]]
}

@test "loads local config" {
  create_local_config '{"board_id": "67890"}'

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config "board_id")
  [[ "$result" == "67890" ]]
}

@test "local config overrides global config" {
  create_global_config '{"board_id": "global-123"}'
  create_local_config '{"board_id": "local-456"}'

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config "board_id")
  [[ "$result" == "local-456" ]]
}

@test "environment variable overrides config file" {
  create_global_config '{"account_slug": "from-file"}'
  export FIZZY_ACCOUNT_SLUG="from-env"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config "account_slug")
  [[ "$result" == "from-env" ]]
}


# Config defaults

@test "get_config returns default for missing key" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config "nonexistent" "default-value")
  [[ "$result" == "default-value" ]]
}

@test "has_config returns false for missing key" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  ! has_config "nonexistent"
}

@test "has_config returns true for existing key" {
  create_global_config '{"account_slug": "12345"}'

  source "$FIZZY_ROOT/lib/core.sh"
  FIZZY_GLOBAL_CONFIG_DIR="$HOME/.config/fizzy"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  has_config "account_slug"
}


# Credentials

@test "loads credentials from file" {
  create_credentials "my-test-token" "$(($(date +%s) + 3600))"
  unset FIZZY_ACCESS_TOKEN

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  result=$(get_access_token)
  [[ "$result" == "my-test-token" ]]
}

@test "environment token overrides file" {
  create_credentials "file-token"
  export FIZZY_ACCESS_TOKEN="env-token"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  result=$(get_access_token)
  [[ "$result" == "env-token" ]]
}

@test "is_token_expired returns true for expired token" {
  create_credentials "test-token" "$(($(date +%s) - 100))"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  is_token_expired
}

@test "is_token_expired returns false for valid token" {
  create_credentials "test-token" "$(($(date +%s) + 3600))"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  ! is_token_expired
}


# Account/Board getters

@test "get_account_slug from config" {
  create_global_config '{"account_slug": "99999"}'
  unset FIZZY_ACCOUNT_SLUG
  unset FIZZY_ACCOUNT

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_account_slug)
  [[ "$result" == "99999" ]]
}

@test "get_board_id from config" {
  create_local_config '{"board_id": "88888"}'
  unset FIZZY_BOARD_ID
  unset FIZZY_BOARD

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_board_id)
  [[ "$result" == "88888" ]]
}


# URL configuration

@test "loads base_url from config" {
  create_global_config '{"base_url": "http://dev.example.com"}'
  unset FIZZY_BASE_URL

  source "$FIZZY_ROOT/lib/core.sh"

  [[ "$FIZZY_BASE_URL" == "http://dev.example.com" ]]
}

@test "environment FIZZY_BASE_URL overrides config" {
  create_global_config '{"base_url": "http://from-config.com"}'
  export FIZZY_BASE_URL="http://from-env.com"

  source "$FIZZY_ROOT/lib/core.sh"

  [[ "$FIZZY_BASE_URL" == "http://from-env.com" ]]
}

@test "defaults to dev server when no config" {
  unset FIZZY_BASE_URL

  source "$FIZZY_ROOT/lib/core.sh"

  [[ "$FIZZY_BASE_URL" == "http://fizzy.localhost:3006" ]]
}


# Config Layering

@test "loads system-wide config" {
  create_system_config '{"account_slug": "system-123"}'

  source "$FIZZY_ROOT/lib/core.sh"
  FIZZY_SYSTEM_CONFIG_DIR="$TEST_TEMP_DIR/etc/fizzy"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config "account_slug")
  [[ "$result" == "system-123" ]]
}

@test "user config overrides system config" {
  create_system_config '{"account_slug": "system-123"}'
  create_global_config '{"account_slug": "user-456"}'

  source "$FIZZY_ROOT/lib/core.sh"
  FIZZY_SYSTEM_CONFIG_DIR="$TEST_TEMP_DIR/etc/fizzy"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config "account_slug")
  [[ "$result" == "user-456" ]]
}

@test "repo config detected from git root" {
  init_git_repo "$TEST_PROJECT"
  mkdir -p "$TEST_PROJECT/subdir"
  create_repo_config '{"board_id": "repo-789"}' "$TEST_PROJECT"

  cd "$TEST_PROJECT/subdir"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config "board_id")
  [[ "$result" == "repo-789" ]]
}

@test "repo config overrides user config" {
  init_git_repo "$TEST_PROJECT"
  create_global_config '{"board_id": "user-config"}'
  create_repo_config '{"board_id": "repo-config"}' "$TEST_PROJECT"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config "board_id")
  [[ "$result" == "repo-config" ]]
}

@test "local config overrides repo config" {
  init_git_repo "$TEST_PROJECT"
  mkdir -p "$TEST_PROJECT/subdir/.fizzy"
  create_repo_config '{"board_id": "repo-config"}' "$TEST_PROJECT"
  echo '{"board_id": "local-config"}' > "$TEST_PROJECT/subdir/.fizzy/config.json"

  cd "$TEST_PROJECT/subdir"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config "board_id")
  [[ "$result" == "local-config" ]]
}

@test "full config layering priority" {
  # Set up all 6 layers
  create_system_config '{"account_slug": "system", "board_id": "system", "column_id": "system"}'
  create_global_config '{"account_slug": "user", "board_id": "user", "column_id": "user"}'
  init_git_repo "$TEST_PROJECT"
  create_repo_config '{"account_slug": "repo", "board_id": "repo", "column_id": "repo"}' "$TEST_PROJECT"
  mkdir -p "$TEST_PROJECT/subdir/.fizzy"
  echo '{"board_id": "local", "column_id": "local"}' > "$TEST_PROJECT/subdir/.fizzy/config.json"
  export FIZZY_COLUMN_ID="env"

  cd "$TEST_PROJECT/subdir"

  source "$FIZZY_ROOT/lib/core.sh"
  FIZZY_SYSTEM_CONFIG_DIR="$TEST_TEMP_DIR/etc/fizzy"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config

  # account_slug: local doesn't set, env doesn't set, so repo wins
  result=$(get_config "account_slug")
  [[ "$result" == "repo" ]]

  # board_id: local sets it
  result=$(get_config "board_id")
  [[ "$result" == "local" ]]

  # column_id: env overrides all files
  result=$(get_config "column_id")
  [[ "$result" == "env" ]]
}


# Column ID getter

@test "get_column_id from config" {
  create_local_config '{"column_id": "77777"}'
  unset FIZZY_COLUMN_ID

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_column_id)
  [[ "$result" == "77777" ]]
}

@test "get_column_id from environment" {
  create_local_config '{"column_id": "from-file"}'
  export FIZZY_COLUMN_ID="from-env"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_column_id)
  [[ "$result" == "from-env" ]]
}


# Config source tracking

@test "get_config_source returns env for environment variable" {
  export FIZZY_ACCOUNT_SLUG="from-env"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config_source "account_slug")
  [[ "$result" == "env" ]]
}

@test "get_config_source returns flag for FIZZY_ACCOUNT" {
  export FIZZY_ACCOUNT="from-flag"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config_source "account_slug")
  [[ "$result" == "flag" ]]
}

@test "get_config_source returns local for cwd config" {
  create_local_config '{"board_id": "from-local"}'

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config_source "board_id")
  [[ "$result" == *"local"* ]]
}

@test "get_config_source returns user for global config" {
  create_global_config '{"account_slug": "from-user"}'
  unset FIZZY_ACCOUNT_SLUG
  unset FIZZY_ACCOUNT

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config_source "account_slug")
  [[ "$result" == *"user"* ]]
}

@test "get_config_source returns system for system-wide config" {
  create_system_config '{"account_slug": "from-system"}'
  unset FIZZY_ACCOUNT_SLUG
  unset FIZZY_ACCOUNT

  source "$FIZZY_ROOT/lib/core.sh"
  FIZZY_SYSTEM_CONFIG_DIR="$TEST_TEMP_DIR/etc/fizzy"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config_source "account_slug")
  [[ "$result" == *"system"* ]]
}

@test "get_config_source returns repo for git root config" {
  init_git_repo "$TEST_PROJECT"
  create_repo_config '{"board_id": "from-repo"}' "$TEST_PROJECT"
  mkdir -p "$TEST_PROJECT/subdir"

  cd "$TEST_PROJECT/subdir"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config_source "board_id")
  [[ "$result" == *"repo"* ]]
}

@test "get_config_source returns unset for missing key" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  load_config
  result=$(get_config_source "nonexistent")
  [[ "$result" == "unset" ]]
}


# Token scope

@test "get_token_scope returns scope from credentials" {
  create_credentials "test-token" "$(($(date +%s) + 3600))" "write"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  result=$(get_token_scope)
  [[ "$result" == "write" ]]
}

@test "get_token_scope returns unknown when no scope" {
  create_credentials "test-token" "$(($(date +%s) + 3600))"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  # get_token_scope returns "unknown" and exit code 1 when no scope
  result=$(get_token_scope 2>/dev/null) || true
  [[ "$result" == "unknown" ]]
}


# fizzy config command

@test "config --help shows help" {
  run fizzy --md config --help
  assert_success
  assert_output_contains "fizzy config"
  assert_output_contains "Manage configuration"
}

@test "config -h shows help" {
  run fizzy --md config -h
  assert_success
  assert_output_contains "fizzy config"
}

@test "config --help --json outputs JSON" {
  run fizzy --json config --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}

@test "config list shows configuration" {
  create_global_config '{"account_slug": "12345"}'

  run fizzy --md config
  assert_success
  assert_output_contains "Configuration"
}

@test "config list --json outputs JSON" {
  create_global_config '{"account_slug": "12345"}'

  run fizzy --json config list
  assert_success
  is_valid_json
}

@test "config get retrieves value" {
  create_global_config '{"account_slug": "test-slug"}'
  unset FIZZY_ACCOUNT_SLUG
  unset FIZZY_ACCOUNT

  run fizzy config get account_slug
  assert_success
  assert_output_contains "test-slug"
}

@test "config get missing key shows error" {
  run fizzy config get nonexistent
  assert_failure
  assert_output_contains "Key not found"
}

@test "config set creates value" {
  run fizzy config set my_key my_value
  assert_success
  assert_output_contains "Set my_key"

  # Verify it was saved to local config (cwd/.fizzy/config.json)
  local config_file="$TEST_PROJECT/.fizzy/config.json"
  [[ -f "$config_file" ]]
  result=$(jq -r '.my_key' "$config_file")
  [[ "$result" == "my_value" ]]
}

@test "config set --global creates global value" {
  run fizzy config set --global my_global_key my_value
  assert_success
  assert_output_contains "global"

  # Verify it was saved to global config (~/.config/fizzy/config.json)
  local config_file="$TEST_HOME/.config/fizzy/config.json"
  [[ -f "$config_file" ]]
  result=$(jq -r '.my_global_key' "$config_file")
  [[ "$result" == "my_value" ]]
}

@test "config unset removes value" {
  create_local_config '{"my_key": "my_value"}'

  run fizzy config unset my_key
  assert_success
  assert_output_contains "Unset my_key"

  # Verify it was removed from local config
  local config_file="$TEST_PROJECT/.fizzy/config.json"
  result=$(jq -r '.my_key // empty' "$config_file")
  [[ -z "$result" ]]
}

@test "config path shows paths" {
  run fizzy --md config path
  assert_success
  assert_output_contains "Config Paths"
  assert_output_contains "global"
  assert_output_contains "local"
}

@test "config path --json outputs JSON" {
  run fizzy --json config path
  assert_success
  is_valid_json
  assert_json_not_null ".global"
  assert_json_not_null ".local"
}

@test "local config base_url overrides global" {
  create_global_config '{"base_url": "http://global.example.com"}'
  create_local_config '{"base_url": "http://local.example.com"}'
  unset FIZZY_BASE_URL

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  # After loading full hierarchy, local should win
  [[ "$FIZZY_BASE_URL" == "http://local.example.com" ]]
}
