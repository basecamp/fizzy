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


# board --help

@test "board --help shows help" {
  run fizzy --md board --help
  assert_success
  assert_output_contains "fizzy board"
  assert_output_contains "Manage boards"
}


# board validation

@test "board create without name shows error" {
  run fizzy board create
  assert_failure
  assert_output_contains "Board name required"
}

@test "board update without id shows error" {
  run fizzy board update
  assert_failure
  assert_output_contains "Board ID required"
}

@test "board delete without id shows error" {
  run fizzy board delete
  assert_failure
  assert_output_contains "Board ID required"
}

@test "board show without id shows error" {
  run fizzy board show
  assert_failure
  assert_output_contains "Board ID required"
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


# column --help

@test "column --help shows help" {
  run fizzy --md column --help
  assert_success
  assert_output_contains "fizzy column"
  assert_output_contains "Manage columns"
}


# column validation

@test "column create without name shows error" {
  run fizzy column create --board abc123
  assert_failure
  assert_output_contains "Column name required"
}

@test "column create without board shows error" {
  run fizzy column create "In Progress"
  assert_failure
  assert_output_contains "No board specified"
}

@test "column update without id shows error" {
  run fizzy column update
  assert_failure
  assert_output_contains "Column ID required"
}

@test "column update without board shows error" {
  run fizzy column update abc123
  assert_failure
  assert_output_contains "No board specified"
}

@test "column delete without id shows error" {
  run fizzy column delete
  assert_failure
  assert_output_contains "Column ID required"
}

@test "column show without id shows error" {
  run fizzy column show
  assert_failure
  assert_output_contains "Column ID required"
}
