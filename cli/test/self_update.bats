#!/usr/bin/env bats
# self_update.bats - Tests for version, self-update, and uninstall commands

load test_helper


# --version flag

@test "fizzy --version shows version" {
  run fizzy --version
  assert_success
  assert_output_contains "fizzy"
  assert_output_contains "main"
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


# self-update guards

@test "self-update detects git checkout and suggests git pull" {
  # Create a fake .git directory to simulate git checkout
  mkdir -p "$FIZZY_ROOT/.git"
  run fizzy --json self-update
  rmdir "$FIZZY_ROOT/.git"
  assert_failure
  assert_output_contains "git checkout"
  assert_output_contains "git pull"
}

@test "self-update --check also detects git checkout" {
  mkdir -p "$FIZZY_ROOT/.git"
  run fizzy --json self-update --check
  rmdir "$FIZZY_ROOT/.git"
  assert_failure
  assert_output_contains "git checkout"
}


# uninstall --help

@test "uninstall --help shows help" {
  run fizzy --md uninstall --help
  assert_success
  assert_output_contains "fizzy uninstall"
  assert_output_contains "Remove fizzy CLI"
}

@test "uninstall -h shows help" {
  run fizzy --md uninstall -h
  assert_success
  assert_output_contains "fizzy uninstall"
}

@test "uninstall --help --json outputs JSON" {
  run fizzy --json uninstall --help
  assert_success
  is_valid_json
  assert_json_value ".command" "fizzy uninstall"
}


# uninstall guards

@test "uninstall detects git checkout" {
  mkdir -p "$FIZZY_ROOT/.git"
  run fizzy --json uninstall
  rmdir "$FIZZY_ROOT/.git"
  assert_failure
  assert_output_contains "git checkout"
}

@test "uninstall without --force shows confirmation" {
  # Skip this test if running from git checkout (which it always is in dev)
  if [[ -d "$FIZZY_ROOT/.git" ]]; then
    skip "Running from git checkout"
  fi
  run fizzy --md uninstall
  assert_success
  assert_output_contains "This will remove fizzy"
  assert_output_contains "--force"
}
