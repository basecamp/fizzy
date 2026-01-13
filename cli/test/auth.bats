#!/usr/bin/env bats
# auth.bats - Tests for lib/auth.sh

load test_helper


# Auth status

@test "auth status shows unauthenticated when no credentials" {
  run fizzy --md auth status
  assert_success
  assert_output_contains "Not authenticated"
}

@test "auth status --json shows unauthenticated" {
  run fizzy --json auth status
  assert_success
  is_valid_json
  assert_json_value ".status" "unauthenticated"
}

@test "auth status shows authenticated with valid credentials" {
  create_credentials "test-token" "$(($(date +%s) + 3600))" "write"
  create_accounts

  run fizzy --md auth status
  assert_success
  assert_output_contains "Authenticated"
}

@test "auth status --json shows authenticated" {
  create_credentials "test-token" "$(($(date +%s) + 3600))" "write"

  run fizzy --json auth status
  assert_success
  is_valid_json
  assert_json_value ".status" "authenticated"
  assert_json_value ".token" "valid"
}

@test "auth status shows expired token warning" {
  create_credentials "test-token" "$(($(date +%s) - 100))" "write"

  run fizzy --md auth status
  assert_success
  assert_output_contains "Expired"
}

@test "auth status --json shows expired token" {
  create_credentials "test-token" "$(($(date +%s) - 100))" "write"

  run fizzy --json auth status
  assert_success
  is_valid_json
  assert_json_value ".token" "expired"
}


# Auth logout

@test "auth logout removes credentials file" {
  create_credentials "test-token"

  run fizzy auth logout
  assert_success
  assert_output_contains "Logged out"

  [[ ! -f "$TEST_HOME/.config/fizzy/credentials.json" ]]
}

@test "auth logout when not logged in" {
  run fizzy auth logout
  assert_success
  assert_output_contains "Not logged in"
}


# Auth help

@test "auth --help shows help" {
  run fizzy auth --help
  assert_success
  assert_output_contains "login"
  assert_output_contains "logout"
  assert_output_contains "status"
}

@test "auth -h shows help" {
  run fizzy auth -h
  assert_success
  assert_output_contains "login"
}


# Auth scope display

@test "auth status shows write scope" {
  create_credentials "test-token" "$(($(date +%s) + 3600))" "write"

  run fizzy --md auth status
  assert_success
  assert_output_contains "write"
  assert_output_contains "read+write"
}

@test "auth status shows read scope" {
  create_credentials "test-token" "$(($(date +%s) + 3600))" "read"

  run fizzy --md auth status
  assert_success
  assert_output_contains "read"
  assert_output_contains "read-only"
}


# PKCE helpers (testing internal functions)

@test "_generate_code_verifier produces 43+ char string" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/auth.sh"

  result=$(_generate_code_verifier)
  [[ ${#result} -ge 43 ]]
}

@test "_generate_code_challenge produces non-empty string" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/auth.sh"

  verifier=$(_generate_code_verifier)
  result=$(_generate_code_challenge "$verifier")
  [[ -n "$result" ]]
}

@test "_generate_state produces 32 char hex string" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/auth.sh"

  result=$(_generate_state)
  [[ ${#result} -eq 32 ]]
  [[ "$result" =~ ^[0-9a-f]+$ ]]
}


# Client loading

@test "_load_client returns failure when no client file" {
  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/auth.sh"

  ! _load_client
}

@test "_load_client sets client_id from file" {
  create_client

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/auth.sh"

  _load_client
  [[ "$client_id" == "test-client-id" ]]
}


# Account selection

@test "account name shown in status with single account" {
  create_credentials "test-token" "$(($(date +%s) + 3600))"
  create_global_config '{"account_slug": "99999999"}'
  cat > "$TEST_HOME/.config/fizzy/accounts.json" << 'EOF'
[
  {"id": "test-id", "name": "Test Account", "slug": "/99999999"}
]
EOF

  run fizzy --md auth status
  assert_success
  assert_output_contains "Test Account"
}


# Unknown auth action

@test "auth unknown action shows error" {
  run fizzy auth unknownaction
  assert_failure
  assert_output_contains "Unknown auth action"
}


# Long-lived tokens (Fizzy's token model)

@test "auth status shows long-lived token" {
  create_long_lived_credentials "test-token" "write"

  run fizzy --md auth status
  assert_success
  assert_output_contains "Authenticated"
  assert_output_contains "Long-lived"
}

@test "auth status --json shows long-lived token" {
  create_long_lived_credentials "test-token" "write"

  run fizzy --json auth status
  assert_success
  is_valid_json
  assert_json_value ".status" "authenticated"
  assert_json_value ".token" "long-lived"
}

@test "is_token_expired returns false for long-lived token" {
  create_long_lived_credentials "test-token" "write"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  ! is_token_expired
}

@test "auth refresh with long-lived token shows informative message" {
  create_long_lived_credentials "test-token" "write"
  create_accounts

  run fizzy --md auth refresh
  assert_success
  assert_output_contains "long-lived"
  assert_output_contains "doesn't require refresh"
}

@test "auth status treats expires_at 0 as long-lived" {
  # Create credentials with expires_at: 0 (edge case)
  cat > "$TEST_HOME/.config/fizzy/credentials.json" << EOF
{
  "access_token": "test-token",
  "refresh_token": "",
  "scope": "write",
  "expires_at": 0
}
EOF
  chmod 600 "$TEST_HOME/.config/fizzy/credentials.json"

  run fizzy --md auth status
  assert_success
  assert_output_contains "Authenticated"
  assert_output_contains "Long-lived"
}

@test "auth refresh treats expires_at 0 as long-lived" {
  # Create credentials with expires_at: 0 (edge case)
  cat > "$TEST_HOME/.config/fizzy/credentials.json" << EOF
{
  "access_token": "test-token",
  "refresh_token": "",
  "scope": "write",
  "expires_at": 0
}
EOF
  chmod 600 "$TEST_HOME/.config/fizzy/credentials.json"
  create_accounts

  run fizzy --md auth refresh
  assert_success
  assert_output_contains "long-lived"
  assert_output_contains "doesn't require refresh"
}

@test "is_token_expired returns false for expires_at 0" {
  cat > "$TEST_HOME/.config/fizzy/credentials.json" << EOF
{
  "access_token": "test-token",
  "refresh_token": "",
  "scope": "write",
  "expires_at": 0
}
EOF
  chmod 600 "$TEST_HOME/.config/fizzy/credentials.json"

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"

  ! is_token_expired
}

@test "auth refresh without refresh_token but with expiry prompts re-login" {
  # Token has expiry but no refresh token - should prompt re-login
  cat > "$TEST_HOME/.config/fizzy/credentials.json" << EOF
{
  "access_token": "test-token",
  "refresh_token": "",
  "scope": "write",
  "expires_at": $(($(date +%s) + 3600))
}
EOF
  chmod 600 "$TEST_HOME/.config/fizzy/credentials.json"

  run fizzy auth refresh
  assert_failure
  assert_output_contains "No refresh token available"
  assert_output_contains "fizzy auth login"
}

@test "refresh_token uses discovered token endpoint" {
  # This test verifies that refresh_token() calls _token_endpoint() from discovery
  # rather than hardcoding the endpoint path

  # Create credentials with a refresh token
  cat > "$TEST_HOME/.config/fizzy/credentials.json" << EOF
{
  "access_token": "old-token",
  "refresh_token": "test-refresh-token",
  "scope": "write",
  "expires_at": $(($(date +%s) - 100))
}
EOF
  chmod 600 "$TEST_HOME/.config/fizzy/credentials.json"

  # Create client credentials
  create_client

  source "$FIZZY_ROOT/lib/core.sh"
  source "$FIZZY_ROOT/lib/config.sh"
  source "$FIZZY_ROOT/lib/api.sh"

  # Stub _token_endpoint to return a test URL and verify it's called
  _token_endpoint() {
    echo "https://discovered.example.com/oauth/token"
  }

  # Stub curl to capture the URL it's called with
  curl() {
    # Find the URL argument (last positional arg after all options)
    local url=""
    for arg in "$@"; do
      if [[ "$arg" == http* ]]; then
        url="$arg"
      fi
    done
    echo "CURL_URL=$url" >&2
    # Return a failure response so refresh_token returns 1
    echo '{"error": "test_stub"}'
  }

  # Run refresh_token and capture stderr
  output=$(refresh_token 2>&1) || true

  # Verify the discovered endpoint was used
  [[ "$output" == *"https://discovered.example.com/oauth/token"* ]]
}

@test "auth refresh when not authenticated fails" {
  # No credentials file exists
  run fizzy auth refresh
  assert_failure
  assert_output_contains "Not authenticated"
  assert_output_contains "fizzy auth login"
}
