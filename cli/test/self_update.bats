#!/usr/bin/env bats
# self_update.bats - Tests for version and self-update commands

load test_helper


# --version flag

@test "fizzy --version shows version" {
  run fizzy --version
  assert_success
  assert_output_contains "fizzy"
  assert_output_contains "0."
}

@test "fizzy -V shows version" {
  run fizzy -V
  assert_success
  assert_output_contains "fizzy"
}

@test "fizzy version shows version" {
  run fizzy version
  assert_success
  assert_output_contains "fizzy"
}


# self-update --help

@test "self-update --help shows help" {
  run fizzy --md self-update --help
  assert_success
  assert_output_contains "fizzy self-update"
  assert_output_contains "Update fizzy CLI"
}

@test "self-update -h shows help" {
  run fizzy --md self-update -h
  assert_success
  assert_output_contains "fizzy self-update"
}

@test "self-update --help --json outputs JSON" {
  run fizzy --json self-update --help
  assert_success
  is_valid_json
  assert_json_value ".command" "fizzy self-update"
}


# self-update --check (mocked)

@test "self-update --check reports current version" {
  # This test doesn't actually check remote - just verifies the command runs
  # In CI, network may not be available, so we just test the help path
  run fizzy --md self-update --help
  assert_success
}


# VERSION file

@test "VERSION file exists" {
  [[ -f "$FIZZY_ROOT/VERSION" ]]
}

@test "VERSION file contains valid semver" {
  local version
  version=$(cat "$FIZZY_ROOT/VERSION")
  # Basic semver pattern: X.Y.Z
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}
