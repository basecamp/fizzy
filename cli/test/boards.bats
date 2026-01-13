#!/usr/bin/env bats
# boards.bats - Tests for board and column commands

load test_helper


# boards --help

@test "boards --help shows help" {
  run fizzy --md boards --help
  assert_success
  assert_output_contains "fizzy boards"
  assert_output_contains "List boards"
}

@test "boards -h shows help" {
  run fizzy --md boards -h
  assert_success
  assert_output_contains "fizzy boards"
}

@test "boards --help --json outputs JSON" {
  run fizzy --json boards --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# boards requires auth

@test "boards requires authentication" {
  run fizzy boards
  assert_failure
  assert_output_contains "Not authenticated"
}


# boards pagination validation

@test "boards --page rejects non-numeric value" {
  run fizzy boards --page abc
  assert_failure
  assert_output_contains "positive integer"
}

@test "boards --page rejects zero" {
  run fizzy boards --page 0
  assert_failure
  assert_output_contains "positive integer"
}

@test "boards --page rejects negative" {
  run fizzy boards --page -1
  assert_failure
  assert_output_contains "positive integer"
}


# boards --all flag

@test "boards --help documents --all flag" {
  run fizzy --md boards --help
  assert_success
  assert_output_contains "--all"
  assert_output_contains "Fetch all pages"
}


# columns --help

@test "columns --help shows help" {
  run fizzy --md columns --help
  assert_success
  assert_output_contains "fizzy columns"
  assert_output_contains "List columns"
}

@test "columns -h shows help" {
  run fizzy --md columns -h
  assert_success
  assert_output_contains "fizzy columns"
}


# columns requires board

@test "columns without board shows error" {
  create_credentials "test-token" "$(($(date +%s) + 3600))"
  create_global_config '{"account_slug": "12345"}'

  run fizzy columns
  assert_failure
  assert_output_contains "No board"
}

@test "columns uses board from config" {
  # This would require a mock API, so just test the help for now
  run fizzy --md columns --help
  assert_success
  assert_output_contains "--board"
}
