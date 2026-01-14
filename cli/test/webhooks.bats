#!/usr/bin/env bats
# webhooks.bats - Tests for webhook commands

load test_helper


# webhook --help

@test "webhook --help shows help" {
  run fizzy --md webhook --help
  assert_success
  assert_output_contains "fizzy webhook"
  assert_output_contains "Manage webhooks"
}

@test "webhook -h shows help" {
  run fizzy --md webhook -h
  assert_success
  assert_output_contains "fizzy webhook"
}

@test "webhook --help --json outputs JSON" {
  run fizzy --json webhook --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# webhook create --help

@test "webhook create --help shows help" {
  run fizzy --md webhook create --help
  assert_success
  assert_output_contains "fizzy webhook create"
  assert_output_contains "Create a webhook"
}

@test "webhook create -h shows help" {
  run fizzy --md webhook create -h
  assert_success
  assert_output_contains "fizzy webhook create"
}

@test "webhook create --help --json outputs JSON" {
  run fizzy --json webhook create --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}

@test "webhook create --help lists all available actions" {
  # This test locks the available actions to match Webhook::PERMITTED_ACTIONS
  run fizzy --md webhook create --help
  assert_success
  assert_output_contains "card_assigned"
  assert_output_contains "card_closed"
  assert_output_contains "card_postponed"
  assert_output_contains "card_auto_postponed"
  assert_output_contains "card_board_changed"
  assert_output_contains "card_published"
  assert_output_contains "card_reopened"
  assert_output_contains "card_sent_back_to_triage"
  assert_output_contains "card_triaged"
  assert_output_contains "card_unassigned"
  assert_output_contains "comment_created"
}

@test "webhook create --help --json lists all available actions" {
  # This test locks the available actions to match Webhook::PERMITTED_ACTIONS
  run fizzy --json webhook create --help
  assert_success
  is_valid_json

  # Verify all 11 permitted actions are present
  assert_json_contains ".available_actions[]" "card_assigned"
  assert_json_contains ".available_actions[]" "card_closed"
  assert_json_contains ".available_actions[]" "card_postponed"
  assert_json_contains ".available_actions[]" "card_auto_postponed"
  assert_json_contains ".available_actions[]" "card_board_changed"
  assert_json_contains ".available_actions[]" "card_published"
  assert_json_contains ".available_actions[]" "card_reopened"
  assert_json_contains ".available_actions[]" "card_sent_back_to_triage"
  assert_json_contains ".available_actions[]" "card_triaged"
  assert_json_contains ".available_actions[]" "card_unassigned"
  assert_json_contains ".available_actions[]" "comment_created"
}


# webhook create validation

@test "webhook create without --board shows error" {
  run fizzy webhook create --name "Test" --url "https://example.com"
  assert_failure
  assert_output_contains "Board"
}

@test "webhook create without --name shows error" {
  run fizzy webhook create --board "Test" --url "https://example.com"
  assert_failure
  assert_output_contains "name"
}

@test "webhook create without --url shows error" {
  run fizzy webhook create --board "Test" --name "Test"
  assert_failure
  assert_output_contains "url"
}


# webhook show --help

@test "webhook show --help shows help" {
  run fizzy --md webhook show --help
  assert_success
  assert_output_contains "fizzy webhook show"
}

@test "webhook show -h shows help" {
  run fizzy --md webhook show -h
  assert_success
  assert_output_contains "fizzy webhook show"
}

@test "webhook show --help --json outputs JSON" {
  run fizzy --json webhook show --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# webhook delete --help

@test "webhook delete --help shows help" {
  run fizzy --md webhook delete --help
  assert_success
  assert_output_contains "fizzy webhook delete"
}

@test "webhook delete -h shows help" {
  run fizzy --md webhook delete -h
  assert_success
  assert_output_contains "fizzy webhook delete"
}

@test "webhook delete --help --json outputs JSON" {
  run fizzy --json webhook delete --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}
