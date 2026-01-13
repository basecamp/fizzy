#!/usr/bin/env bats
# queries.bats - Tests for query commands (tags, people, notifications)

load test_helper


# tags --help

@test "tags --help shows help" {
  run fizzy --md tags --help
  assert_success
  assert_output_contains "fizzy tags"
  assert_output_contains "List tags"
}

@test "tags -h shows help" {
  run fizzy --md tags -h
  assert_success
  assert_output_contains "fizzy tags"
}

@test "tags --help --json outputs JSON" {
  run fizzy --json tags --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# tags pagination validation

@test "tags --page rejects non-numeric value" {
  run fizzy tags --page abc
  assert_failure
  assert_output_contains "positive integer"
}

@test "tags --page rejects zero" {
  run fizzy tags --page 0
  assert_failure
  assert_output_contains "positive integer"
}


# tags --all flag

@test "tags --help documents --all flag" {
  run fizzy --md tags --help
  assert_success
  assert_output_contains "--all"
  assert_output_contains "Fetch all pages"
}


# people --help

@test "people --help shows help" {
  run fizzy --md people --help
  assert_success
  assert_output_contains "fizzy people"
  assert_output_contains "List users"
}

@test "people -h shows help" {
  run fizzy --md people -h
  assert_success
  assert_output_contains "fizzy people"
}

@test "people --help --json outputs JSON" {
  run fizzy --json people --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# people pagination validation

@test "people --page rejects non-numeric value" {
  run fizzy people --page abc
  assert_failure
  assert_output_contains "positive integer"
}

@test "people --page rejects zero" {
  run fizzy people --page 0
  assert_failure
  assert_output_contains "positive integer"
}


# people --all flag

@test "people --help documents --all flag" {
  run fizzy --md people --help
  assert_success
  assert_output_contains "--all"
  assert_output_contains "Fetch all pages"
}


# notifications --help

@test "notifications --help shows help" {
  run fizzy --md notifications --help
  assert_success
  assert_output_contains "fizzy notifications"
  assert_output_contains "List"
}

@test "notifications -h shows help" {
  run fizzy --md notifications -h
  assert_success
  assert_output_contains "fizzy notifications"
}

@test "notifications --help --json outputs JSON" {
  run fizzy --json notifications --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# notifications pagination validation

@test "notifications --page rejects non-numeric value" {
  run fizzy notifications --page abc
  assert_failure
  assert_output_contains "positive integer"
}

@test "notifications --page rejects zero" {
  run fizzy notifications --page 0
  assert_failure
  assert_output_contains "positive integer"
}


# notifications --all flag

@test "notifications --help documents --all flag" {
  run fizzy --md notifications --help
  assert_success
  assert_output_contains "--all"
  assert_output_contains "Fetch all pages"
}
