#!/usr/bin/env bats
# cards.bats - Tests for card commands

load test_helper


# cards --help

@test "cards --help shows help" {
  run fizzy --md cards --help
  assert_success
  assert_output_contains "fizzy cards"
  assert_output_contains "List and filter"
}

@test "cards -h shows help" {
  run fizzy --md cards -h
  assert_success
  assert_output_contains "fizzy cards"
}

@test "cards --help --json outputs JSON" {
  run fizzy --json cards --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
  assert_json_not_null ".options"
}


# cards requires auth

@test "cards requires authentication" {
  run fizzy cards
  assert_failure
  assert_output_contains "Not authenticated"
}


# cards option parsing

@test "cards rejects unknown option" {
  run fizzy cards --unknown-option
  assert_failure
  assert_output_contains "Unknown option"
}

@test "cards --page rejects non-numeric value" {
  run fizzy cards --page abc
  assert_failure
  assert_output_contains "positive integer"
}

@test "cards --page rejects zero" {
  run fizzy cards --page 0
  assert_failure
  assert_output_contains "positive integer"
}

@test "cards --page rejects negative" {
  run fizzy cards --page -1
  assert_failure
  assert_output_contains "positive integer"
}


# show --help

@test "show --help shows help" {
  run fizzy --md show --help
  assert_success
  assert_output_contains "fizzy show"
}

@test "show -h shows help" {
  run fizzy --md show -h
  assert_success
  assert_output_contains "fizzy show"
}

@test "show --help --json outputs JSON" {
  run fizzy --json show --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# show requires auth

@test "show card requires authentication" {
  run fizzy show 42
  assert_failure
  assert_output_contains "Not authenticated"
}

@test "show board requires authentication" {
  run fizzy show board abc123
  assert_failure
  assert_output_contains "Not authenticated"
}


# search --help

@test "search --help shows help" {
  run fizzy --md search --help
  assert_success
  assert_output_contains "fizzy search"
}

@test "search -h shows help" {
  run fizzy --md search -h
  assert_success
  assert_output_contains "fizzy search"
}


# search requires query

@test "search without query shows error" {
  run fizzy search
  assert_failure
  assert_output_contains "query required"
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


# people requires auth

@test "people requires authentication" {
  run fizzy people
  assert_failure
  assert_output_contains "Not authenticated"
}


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


# tags requires auth

@test "tags requires authentication" {
  run fizzy tags
  assert_failure
  assert_output_contains "Not authenticated"
}


# comments --help

@test "comments --help shows help" {
  run fizzy --md comments --help
  assert_success
  assert_output_contains "fizzy comments"
}

@test "comments -h shows help" {
  run fizzy --md comments -h
  assert_success
  assert_output_contains "fizzy comments"
}


# comments requires card number

@test "comments without card shows error" {
  run fizzy comments
  assert_failure
  assert_output_contains "Card number required"
}


# notifications --help

@test "notifications --help shows help" {
  run fizzy --md notifications --help
  assert_success
  assert_output_contains "fizzy notifications"
}

@test "notifications -h shows help" {
  run fizzy --md notifications -h
  assert_success
  assert_output_contains "fizzy notifications"
}


# notifications requires auth

@test "notifications requires authentication" {
  run fizzy notifications
  assert_failure
  assert_output_contains "Not authenticated"
}
