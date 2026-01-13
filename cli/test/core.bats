#!/usr/bin/env bats
# core.bats - Tests for lib/core.sh

load test_helper


# Version

@test "fizzy shows version" {
  run fizzy version
  assert_success
  assert_output_contains "fizzy"
}


# Quick start

@test "fizzy with no args shows quick start" {
  run fizzy
  assert_success
  assert_output_contains "fizzy"
}

@test "fizzy --json with no args outputs JSON" {
  run fizzy --json
  assert_success
  is_valid_json
  assert_json_not_null ".version"
}


# Help

@test "fizzy --help shows help" {
  run fizzy --md --help
  assert_success
  assert_output_contains "USAGE"
  assert_output_contains "COMMANDS"
}

@test "fizzy help shows main help" {
  run fizzy help
  assert_success
  assert_output_contains "fizzy"
}


# Output format detection

@test "fizzy defaults to markdown when TTY" {
  # This is tricky to test since bats runs in non-TTY
  # For now, just verify --md flag works
  run fizzy --md
  assert_success
  assert_output_not_contains '"version"'
}

@test "fizzy --json forces JSON output" {
  run fizzy --json
  assert_success
  is_valid_json
}


# Global flags

@test "fizzy respects --quiet flag" {
  run fizzy --quiet version
  assert_success
}

@test "fizzy respects --verbose flag" {
  run fizzy --verbose version
  assert_success
}


# Error handling

@test "fizzy unknown command shows error" {
  run fizzy notacommand
  assert_failure
}


# JSON envelope structure

@test "JSON output has correct envelope structure" {
  run fizzy --json
  assert_success
  is_valid_json

  # Check required fields
  assert_json_not_null ".version"
  assert_json_not_null ".auth"
}


# Exit codes

@test "unknown command returns exit code 1" {
  run fizzy unknowncommand
  assert_exit_code 1
}


# Format flag aliases

@test "fizzy -j is alias for --json" {
  run fizzy -j
  assert_success
  is_valid_json
}

@test "fizzy -m is alias for --md" {
  run fizzy -m
  assert_success
  assert_output_not_contains '"version"'
}

@test "fizzy -q is alias for --quiet" {
  run fizzy -q version
  assert_success
}

@test "fizzy -v is alias for --verbose" {
  run fizzy -v version
  assert_success
}


# Board and account flags

@test "fizzy --board sets board context" {
  run fizzy --json --board test-board
  assert_success
  # Should not error even without auth
}

@test "fizzy --account sets account context" {
  run fizzy --json --account 12345
  assert_success
}

@test "fizzy -b is alias for --board" {
  run fizzy --json -b test-board
  assert_success
}

@test "fizzy -a is alias for --account" {
  run fizzy --json -a 12345
  assert_success
}
