#!/usr/bin/env bats
# users.bats - Tests for identity and user commands

load test_helper


# Identity command

@test "identity --help shows help" {
  run fizzy identity --help
  assert_success
  assert_output_contains "identity"
  assert_output_contains "accounts"
}

@test "identity -h shows help" {
  run fizzy identity -h
  assert_success
  assert_output_contains "identity"
}

@test "identity --help --json outputs JSON" {
  run fizzy --json identity --help
  assert_success
  is_valid_json
  assert_json_value ".command" "fizzy identity"
}

@test "identity requires authentication" {
  run fizzy identity
  assert_failure
  assert_output_contains "Not authenticated"
}


# User show command

@test "user show --help shows help" {
  run fizzy user show --help
  assert_success
  assert_output_contains "user show"
  assert_output_contains "id|email|name"
}

@test "user show -h shows help" {
  run fizzy user show -h
  assert_success
  assert_output_contains "user show"
}

@test "user show --help --json outputs JSON" {
  run fizzy --json user show --help
  assert_success
  is_valid_json
  assert_json_value ".command" "fizzy user show"
}

@test "user show without argument shows error" {
  create_credentials
  create_global_config '{"account_slug": "99999999"}'

  run fizzy user show
  assert_failure
  assert_output_contains "User ID, email, or name required"
}

@test "user show requires authentication" {
  create_global_config '{"account_slug": "99999999"}'

  run fizzy user show abc123
  assert_failure
  assert_output_contains "Not authenticated"
}

@test "user show requires account_slug" {
  create_credentials

  run fizzy user show abc123
  assert_failure
  assert_output_contains "Account not configured"
}


# User update command

@test "user update --help shows help" {
  run fizzy user update --help
  assert_success
  assert_output_contains "user update"
  assert_output_contains "--name"
  assert_output_contains "--avatar"
}

@test "user update -h shows help" {
  run fizzy user update -h
  assert_success
  assert_output_contains "user update"
}

@test "user update --help --json outputs JSON" {
  run fizzy --json user update --help
  assert_success
  is_valid_json
  assert_json_value ".command" "fizzy user update"
}

@test "user update without argument shows error" {
  create_credentials
  create_global_config '{"account_slug": "99999999"}'

  run fizzy user update
  assert_failure
  assert_output_contains "User ID, email, or name required"
}

@test "user update without options shows error" {
  create_credentials
  create_global_config '{"account_slug": "99999999"}'

  run fizzy user update abc123
  assert_failure
  assert_output_contains "Nothing to update"
}

@test "user update --avatar with missing file shows error" {
  create_credentials
  create_global_config '{"account_slug": "99999999"}'

  run fizzy user update abc123 --avatar /nonexistent/file.jpg
  assert_failure
  assert_output_contains "File not found"
}

@test "user update requires authentication" {
  create_global_config '{"account_slug": "99999999"}'

  run fizzy user update abc123 --name "New Name"
  assert_failure
  assert_output_contains "Not authenticated"
}


# User delete command

@test "user delete --help shows help" {
  run fizzy user delete --help
  assert_success
  assert_output_contains "user delete"
  assert_output_contains "Deactivate"
}

@test "user delete -h shows help" {
  run fizzy user delete -h
  assert_success
  assert_output_contains "user delete"
}

@test "user delete --help --json outputs JSON" {
  run fizzy --json user delete --help
  assert_success
  is_valid_json
  assert_json_value ".command" "fizzy user delete"
}

@test "user delete without argument shows error" {
  create_credentials
  create_global_config '{"account_slug": "99999999"}'

  run fizzy user delete
  assert_failure
  assert_output_contains "User ID, email, or name required"
}

@test "user delete requires authentication" {
  create_global_config '{"account_slug": "99999999"}'

  run fizzy user delete abc123
  assert_failure
  assert_output_contains "Not authenticated"
}


# User command help

@test "user --help shows subcommands" {
  run fizzy user --help
  assert_success
  assert_output_contains "show"
  assert_output_contains "update"
  assert_output_contains "delete"
}

@test "user -h shows subcommands" {
  run fizzy user -h
  assert_success
  assert_output_contains "show"
  assert_output_contains "update"
  assert_output_contains "delete"
}

@test "user without subcommand shows help" {
  run fizzy user
  assert_success
  assert_output_contains "show"
  assert_output_contains "update"
  assert_output_contains "delete"
}

@test "user --help --json outputs JSON" {
  run fizzy --json user --help
  assert_success
  is_valid_json
  assert_json_value ".command" "fizzy user"
}

@test "user unknown subcommand shows error" {
  run fizzy user unknown
  assert_failure
  assert_output_contains "Unknown subcommand"
}
