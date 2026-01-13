#!/usr/bin/env bash
# test_helper.bash - Common test utilities for fizzy tests


# Setup/Teardown

setup() {
  # Store original environment
  _ORIG_HOME="$HOME"
  _ORIG_PWD="$PWD"

  # Create temp directories
  TEST_TEMP_DIR="$(mktemp -d)"
  TEST_HOME="$TEST_TEMP_DIR/home"
  TEST_PROJECT="$TEST_TEMP_DIR/project"

  mkdir -p "$TEST_HOME/.config/fizzy"
  mkdir -p "$TEST_PROJECT/.fizzy"

  # Set up test environment
  export HOME="$TEST_HOME"
  export FIZZY_ROOT="${BATS_TEST_DIRNAME}/.."
  export PATH="$FIZZY_ROOT/bin:$PATH"

  # Clear environment variables that might interfere with tests
  # Tests can set these as needed
  unset FIZZY_ACCESS_TOKEN
  unset FIZZY_ACCOUNT_SLUG
  unset FIZZY_BOARD_ID
  unset FIZZY_COLUMN_ID
  unset FIZZY_ACCOUNT
  unset FIZZY_BOARD

  cd "$TEST_PROJECT"
}

teardown() {
  # Restore original environment
  export HOME="$_ORIG_HOME"
  cd "$_ORIG_PWD"

  # Clean up temp directory
  if [[ -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}


# Assertions

assert_success() {
  if [[ "$status" -ne 0 ]]; then
    echo "Expected success (0), got $status"
    echo "Output: $output"
    return 1
  fi
}

assert_failure() {
  if [[ "$status" -eq 0 ]]; then
    echo "Expected failure (non-zero), got $status"
    echo "Output: $output"
    return 1
  fi
}

assert_exit_code() {
  local expected="$1"
  if [[ "$status" -ne "$expected" ]]; then
    echo "Expected exit code $expected, got $status"
    echo "Output: $output"
    return 1
  fi
}

assert_output_contains() {
  local expected="$1"
  if [[ "$output" != *"$expected"* ]]; then
    echo "Expected output to contain: $expected"
    echo "Actual output: $output"
    return 1
  fi
}

assert_output_not_contains() {
  local unexpected="$1"
  if [[ "$output" == *"$unexpected"* ]]; then
    echo "Expected output NOT to contain: $unexpected"
    echo "Actual output: $output"
    return 1
  fi
}

assert_output_starts_with() {
  local expected="$1"
  if [[ "${output:0:${#expected}}" != "$expected" ]]; then
    echo "Expected output to start with: $expected"
    echo "Actual output starts with: ${output:0:20}"
    return 1
  fi
}

assert_json_value() {
  local path="$1"
  local expected="$2"
  local actual
  actual=$(echo "$output" | jq -r "$path")

  if [[ "$actual" != "$expected" ]]; then
    echo "JSON path $path: expected '$expected', got '$actual'"
    echo "Full output: $output"
    return 1
  fi
}

assert_json_not_null() {
  local path="$1"
  local actual
  actual=$(echo "$output" | jq -r "$path")

  if [[ "$actual" == "null" ]] || [[ -z "$actual" ]]; then
    echo "JSON path $path: expected non-null value, got '$actual'"
    return 1
  fi
}


# Fixtures

create_global_config() {
  # Note: Use quoted default to avoid bash parsing issue with closing braces
  local content="${1:-"{}"}"
  echo "$content" > "$TEST_HOME/.config/fizzy/config.json"
}

create_local_config() {
  # Note: Use quoted default to avoid bash parsing issue with closing braces
  local content="${1:-"{}"}"
  echo "$content" > "$TEST_PROJECT/.fizzy/config.json"
}

create_credentials() {
  local access_token="${1:-test-token}"
  local expires_at="${2:-$(($(date +%s) + 3600))}"
  local scope="${3:-}"
  local base_url="${FIZZY_BASE_URL:-http://fizzy.localhost:3006}"
  # Remove trailing slash for consistent keys
  base_url="${base_url%/}"

  local scope_field=""
  if [[ -n "$scope" ]]; then
    scope_field="\"scope\": \"$scope\","
  fi

  cat > "$TEST_HOME/.config/fizzy/credentials.json" << EOF
{
  "$base_url": {
    "access_token": "$access_token",
    "refresh_token": "test-refresh-token",
    $scope_field
    "expires_at": $expires_at
  }
}
EOF
  chmod 600 "$TEST_HOME/.config/fizzy/credentials.json"
}

# Creates long-lived credentials without expiration (like Fizzy issues)
create_long_lived_credentials() {
  local access_token="${1:-test-token}"
  local scope="${2:-write}"
  local base_url="${FIZZY_BASE_URL:-http://fizzy.localhost:3006}"
  # Remove trailing slash for consistent keys
  base_url="${base_url%/}"

  cat > "$TEST_HOME/.config/fizzy/credentials.json" << EOF
{
  "$base_url": {
    "access_token": "$access_token",
    "refresh_token": "",
    "scope": "$scope",
    "expires_at": null
  }
}
EOF
  chmod 600 "$TEST_HOME/.config/fizzy/credentials.json"
}

create_accounts() {
  local base_url="${FIZZY_BASE_URL:-http://fizzy.localhost:3006}"
  # Remove trailing slash for consistent keys
  base_url="${base_url%/}"

  cat > "$TEST_HOME/.config/fizzy/accounts.json" << EOF
{
  "$base_url": [
    {"id": "test-account-id", "name": "Test Account", "slug": "/99999999"}
  ]
}
EOF
}

create_client() {
  local base_url="${FIZZY_BASE_URL:-http://fizzy.localhost:3006}"
  # Remove trailing slash for consistent keys
  base_url="${base_url%/}"

  cat > "$TEST_HOME/.config/fizzy/client.json" << EOF
{
  "$base_url": {
    "client_id": "test-client-id",
    "client_secret": ""
  }
}
EOF
  chmod 600 "$TEST_HOME/.config/fizzy/client.json"
}

create_system_config() {
  # Note: Use quoted default to avoid bash parsing issue with closing braces
  local content="${1:-"{}"}"
  mkdir -p "$TEST_TEMP_DIR/etc/fizzy"
  echo "$content" > "$TEST_TEMP_DIR/etc/fizzy/config.json"
}

create_repo_config() {
  # Note: Use quoted default to avoid bash parsing issue with closing braces
  local content="${1:-"{}"}"
  local git_root="${2:-$TEST_PROJECT}"
  mkdir -p "$git_root/.fizzy"
  echo "$content" > "$git_root/.fizzy/config.json"
}

init_git_repo() {
  local dir="${1:-$TEST_PROJECT}"
  git -C "$dir" init --quiet 2>/dev/null || true
}


# Mock helpers

mock_api_response() {
  local response="$1"
  export FIZZY_MOCK_RESPONSE="$response"
}


# Utility

is_valid_json() {
  echo "$output" | jq . &>/dev/null
}
