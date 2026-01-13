#!/usr/bin/env bats
# actions.bats - Tests for card action commands (Phase 3)

load test_helper


# card (create) --help

@test "card --help shows help" {
  run fizzy --md card --help
  assert_success
  assert_output_contains "fizzy card"
  assert_output_contains "Create"
}

@test "card -h shows help" {
  run fizzy --md card -h
  assert_success
  assert_output_contains "fizzy card"
}

@test "card --help --json outputs JSON" {
  run fizzy --json card --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
  assert_json_not_null ".options"
}


# card requires title

@test "card without title shows error" {
  run fizzy card
  assert_failure
  assert_output_contains "title required"
}

@test "card requires board" {
  run fizzy card "Test"
  assert_failure
  assert_output_contains "No board specified"
}

@test "card requires authentication with board" {
  create_local_config '{"board_id": "test-board-id"}'
  run fizzy card "Test"
  assert_failure
  assert_output_contains "Not authenticated"
}

@test "card rejects unknown option" {
  run fizzy card --unknown-option
  assert_failure
  assert_output_contains "Unknown option"
}


# update --help

@test "update --help shows help" {
  run fizzy --md update --help
  assert_success
  assert_output_contains "fizzy update"
  assert_output_contains "Update"
}

@test "update -h shows help" {
  run fizzy --md update -h
  assert_success
  assert_output_contains "fizzy update"
}

@test "update --help --json outputs JSON" {
  run fizzy --json update --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
  assert_json_not_null ".options"
}


# update requires card number and options

@test "update without number shows error" {
  run fizzy update
  assert_failure
  assert_output_contains "Card number required"
}

@test "update without options shows error" {
  run fizzy update 123
  assert_failure
  assert_output_contains "Nothing to update"
}

@test "update requires authentication" {
  run fizzy update 123 --title "New"
  assert_failure
  assert_output_contains "Not authenticated"
}

@test "update rejects unknown option" {
  run fizzy update --unknown-option
  assert_failure
  assert_output_contains "Unknown option"
}

@test "update --description-file with missing file shows error" {
  run fizzy update 123 --description-file nonexistent.txt
  assert_failure
  assert_output_contains "File not found"
}


# close --help

@test "close --help shows help" {
  run fizzy --md close --help
  assert_success
  assert_output_contains "fizzy close"
  assert_output_contains "Close"
}

@test "close -h shows help" {
  run fizzy --md close -h
  assert_success
  assert_output_contains "fizzy close"
}

@test "close --help --json outputs JSON" {
  run fizzy --json close --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# close requires card number

@test "close without number shows error" {
  run fizzy close
  assert_failure
  assert_output_contains "Card number required"
}

@test "close requires authentication" {
  run fizzy close 123
  assert_failure
  assert_output_contains "Not authenticated"
}

@test "close rejects unknown option" {
  run fizzy close --unknown-option
  assert_failure
  assert_output_contains "Unknown option"
}


# reopen --help

@test "reopen --help shows help" {
  run fizzy --md reopen --help
  assert_success
  assert_output_contains "fizzy reopen"
  assert_output_contains "Reopen"
}

@test "reopen -h shows help" {
  run fizzy --md reopen -h
  assert_success
  assert_output_contains "fizzy reopen"
}

@test "reopen --help --json outputs JSON" {
  run fizzy --json reopen --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# reopen requires card number

@test "reopen without number shows error" {
  run fizzy reopen
  assert_failure
  assert_output_contains "Card number required"
}

@test "reopen requires authentication" {
  run fizzy reopen 123
  assert_failure
  assert_output_contains "Not authenticated"
}


# delete --help

@test "delete --help shows help" {
  run fizzy --md delete --help
  assert_success
  assert_output_contains "fizzy delete"
  assert_output_contains "delete"
}

@test "delete -h shows help" {
  run fizzy --md delete -h
  assert_success
  assert_output_contains "fizzy delete"
}

@test "delete --help --json outputs JSON" {
  run fizzy --json delete --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}

@test "delete --help shows warning" {
  run fizzy --md delete --help
  assert_success
  assert_output_contains "cannot be undone"
}


# delete requires card number

@test "delete without number shows error" {
  run fizzy delete
  assert_failure
  assert_output_contains "Card number required"
}

@test "delete requires authentication" {
  run fizzy delete 123
  assert_failure
  assert_output_contains "Not authenticated"
}

@test "delete rejects unknown option" {
  run fizzy delete --invalid
  assert_failure
  assert_output_contains "Unknown option"
}


# triage --help

@test "triage --help shows help" {
  run fizzy --md triage --help
  assert_success
  assert_output_contains "fizzy triage"
  assert_output_contains "Move card"
}

@test "triage -h shows help" {
  run fizzy --md triage -h
  assert_success
  assert_output_contains "fizzy triage"
}

@test "triage --help --json outputs JSON" {
  run fizzy --json triage --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
  assert_json_not_null ".options"
}


# triage requires parameters

@test "triage without number shows error" {
  run fizzy triage
  assert_failure
  assert_output_contains "Card number required"
}

@test "triage without --to shows error" {
  run fizzy triage 123
  assert_failure
  assert_output_contains "column ID required"
}

@test "triage without board context shows resolution error" {
  run fizzy triage 123 --to col456
  assert_failure
  assert_output_contains "Cannot resolve column name without board context"
}


# untriage --help

@test "untriage --help shows help" {
  run fizzy --md untriage --help
  assert_success
  assert_output_contains "fizzy untriage"
  assert_output_contains "triage"
}

@test "untriage -h shows help" {
  run fizzy --md untriage -h
  assert_success
  assert_output_contains "fizzy untriage"
}

@test "untriage --help --json outputs JSON" {
  run fizzy --json untriage --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# untriage requires card number

@test "untriage without number shows error" {
  run fizzy untriage
  assert_failure
  assert_output_contains "Card number required"
}

@test "untriage requires authentication" {
  run fizzy untriage 123
  assert_failure
  assert_output_contains "Not authenticated"
}


# postpone --help

@test "postpone --help shows help" {
  run fizzy --md postpone --help
  assert_success
  assert_output_contains "fizzy postpone"
  assert_output_contains "Not Now"
}

@test "postpone -h shows help" {
  run fizzy --md postpone -h
  assert_success
  assert_output_contains "fizzy postpone"
}

@test "postpone --help --json outputs JSON" {
  run fizzy --json postpone --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# postpone requires card number

@test "postpone without number shows error" {
  run fizzy postpone
  assert_failure
  assert_output_contains "Card number required"
}

@test "postpone requires authentication" {
  run fizzy postpone 123
  assert_failure
  assert_output_contains "Not authenticated"
}


# comment --help

@test "comment --help shows help" {
  run fizzy --md comment --help
  assert_success
  assert_output_contains "fizzy comment"
  assert_output_contains "Add comment"
}

@test "comment -h shows help" {
  run fizzy --md comment -h
  assert_success
  assert_output_contains "fizzy comment"
}

@test "comment --help --json outputs JSON" {
  run fizzy --json comment --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
  assert_json_not_null ".options"
}


# comment requires parameters

@test "comment without text shows error" {
  run fizzy comment
  assert_failure
  assert_output_contains "content required"
}

@test "comment without --on shows error" {
  run fizzy comment "Test comment"
  assert_failure
  assert_output_contains "card number required"
}

@test "comment requires authentication" {
  run fizzy comment "Test" --on 123
  assert_failure
  assert_output_contains "Not authenticated"
}


# comment edit --help

@test "comment edit --help shows help" {
  run fizzy --md comment edit --help
  assert_success
  assert_output_contains "fizzy comment edit"
  assert_output_contains "Update"
}

@test "comment edit -h shows help" {
  run fizzy --md comment edit -h
  assert_success
  assert_output_contains "fizzy comment edit"
}

@test "comment edit --help --json outputs JSON" {
  run fizzy --json comment edit --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# comment edit requires arguments

@test "comment edit without args shows error" {
  run fizzy comment edit
  assert_failure
  assert_output_contains "Comment ID required"
}

@test "comment edit without --on shows error" {
  run fizzy comment edit abc123 "new text"
  assert_failure
  assert_output_contains "--on card number required"
}

@test "comment edit without new text shows error" {
  run fizzy comment edit abc123 --on 123
  assert_failure
  assert_output_contains "New comment text required"
}

@test "comment edit requires authentication" {
  run fizzy comment edit abc123 --on 123 "new text"
  assert_failure
  assert_output_contains "Not authenticated"
}


# comment delete --help

@test "comment delete --help shows help" {
  run fizzy --md comment delete --help
  assert_success
  assert_output_contains "fizzy comment delete"
  assert_output_contains "Delete"
}

@test "comment delete -h shows help" {
  run fizzy --md comment delete -h
  assert_success
  assert_output_contains "fizzy comment delete"
}

@test "comment delete --help --json outputs JSON" {
  run fizzy --json comment delete --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# comment delete requires arguments

@test "comment delete without args shows error" {
  run fizzy comment delete
  assert_failure
  assert_output_contains "Comment ID required"
}

@test "comment delete without --on shows error" {
  run fizzy comment delete abc123
  assert_failure
  assert_output_contains "--on card number required"
}

@test "comment delete requires authentication" {
  run fizzy comment delete abc123 --on 123
  assert_failure
  assert_output_contains "Not authenticated"
}


# assign --help

@test "assign --help shows help" {
  run fizzy --md assign --help
  assert_success
  assert_output_contains "fizzy assign"
  assert_output_contains "Toggle assignment"
}

@test "assign -h shows help" {
  run fizzy --md assign -h
  assert_success
  assert_output_contains "fizzy assign"
}

@test "assign --help --json outputs JSON" {
  run fizzy --json assign --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
  assert_json_not_null ".options"
}


# assign requires parameters

@test "assign without number shows error" {
  run fizzy assign
  assert_failure
  assert_output_contains "Card number required"
}

@test "assign without --to shows error" {
  run fizzy assign 123
  assert_failure
  assert_output_contains "user ID required"
}

@test "assign requires authentication" {
  run fizzy assign 123 --to user456
  assert_failure
  assert_output_contains "Not authenticated"
}


# tag --help

@test "tag --help shows help" {
  run fizzy --md tag --help
  assert_success
  assert_output_contains "fizzy tag"
  assert_output_contains "Toggle tag"
}

@test "tag -h shows help" {
  run fizzy --md tag -h
  assert_success
  assert_output_contains "fizzy tag"
}

@test "tag --help --json outputs JSON" {
  run fizzy --json tag --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
  assert_json_not_null ".options"
}


# tag requires parameters

@test "tag without number shows error" {
  run fizzy tag
  assert_failure
  assert_output_contains "Card number required"
}

@test "tag without --with shows error" {
  run fizzy tag 123
  assert_failure
  assert_output_contains "tag name required"
}

@test "tag requires authentication" {
  run fizzy tag 123 --with tag456
  assert_failure
  assert_output_contains "Not authenticated"
}


# watch --help

@test "watch --help shows help" {
  run fizzy --md watch --help
  assert_success
  assert_output_contains "fizzy watch"
  assert_output_contains "Subscribe"
}

@test "watch -h shows help" {
  run fizzy --md watch -h
  assert_success
  assert_output_contains "fizzy watch"
}

@test "watch --help --json outputs JSON" {
  run fizzy --json watch --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# watch requires card number

@test "watch without number shows error" {
  run fizzy watch
  assert_failure
  assert_output_contains "Card number required"
}

@test "watch requires authentication" {
  run fizzy watch 123
  assert_failure
  assert_output_contains "Not authenticated"
}


# unwatch --help

@test "unwatch --help shows help" {
  run fizzy --md unwatch --help
  assert_success
  assert_output_contains "fizzy unwatch"
  assert_output_contains "Unsubscribe"
}

@test "unwatch -h shows help" {
  run fizzy --md unwatch -h
  assert_success
  assert_output_contains "fizzy unwatch"
}

@test "unwatch --help --json outputs JSON" {
  run fizzy --json unwatch --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# unwatch requires card number

@test "unwatch without number shows error" {
  run fizzy unwatch
  assert_failure
  assert_output_contains "Card number required"
}

@test "unwatch requires authentication" {
  run fizzy unwatch 123
  assert_failure
  assert_output_contains "Not authenticated"
}


# gild --help

@test "gild --help shows help" {
  run fizzy --md gild --help
  assert_success
  assert_output_contains "fizzy gild"
  assert_output_contains "golden"
}

@test "gild -h shows help" {
  run fizzy --md gild -h
  assert_success
  assert_output_contains "fizzy gild"
}

@test "gild --help --json outputs JSON" {
  run fizzy --json gild --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# gild requires card number

@test "gild without number shows error" {
  run fizzy gild
  assert_failure
  assert_output_contains "Card number required"
}

@test "gild requires authentication" {
  run fizzy gild 123
  assert_failure
  assert_output_contains "Not authenticated"
}


# ungild --help

@test "ungild --help shows help" {
  run fizzy --md ungild --help
  assert_success
  assert_output_contains "fizzy ungild"
  assert_output_contains "golden"
}

@test "ungild -h shows help" {
  run fizzy --md ungild -h
  assert_success
  assert_output_contains "fizzy ungild"
}

@test "ungild --help --json outputs JSON" {
  run fizzy --json ungild --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
}


# ungild requires card number

@test "ungild without number shows error" {
  run fizzy ungild
  assert_failure
  assert_output_contains "Card number required"
}

@test "ungild requires authentication" {
  run fizzy ungild 123
  assert_failure
  assert_output_contains "Not authenticated"
}


# step --help

@test "step --help shows help" {
  run fizzy --md step --help
  assert_success
  assert_output_contains "fizzy step"
  assert_output_contains "Add step"
}

@test "step -h shows help" {
  run fizzy --md step -h
  assert_success
  assert_output_contains "fizzy step"
}

@test "step --help --json outputs JSON" {
  run fizzy --json step --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
  assert_json_not_null ".options"
}


# step requires parameters

@test "step without text shows error" {
  run fizzy step
  assert_failure
  assert_output_contains "content required"
}

@test "step without --on shows error" {
  run fizzy step "Test step"
  assert_failure
  assert_output_contains "card number required"
}

@test "step requires authentication" {
  run fizzy step "Test" --on 123
  assert_failure
  assert_output_contains "Not authenticated"
}


# react --help

@test "react --help shows help" {
  run fizzy --md react --help
  assert_success
  assert_output_contains "fizzy react"
  assert_output_contains "reaction"
}

@test "react -h shows help" {
  run fizzy --md react -h
  assert_success
  assert_output_contains "fizzy react"
}

@test "react --help --json outputs JSON" {
  run fizzy --json react --help
  assert_success
  is_valid_json
  assert_json_not_null ".command"
  assert_json_not_null ".options"
}


# react requires parameters

@test "react without emoji shows error" {
  run fizzy react
  assert_failure
  assert_output_contains "Emoji required"
}

@test "react without --card shows error" {
  run fizzy react "👍"
  assert_failure
  assert_output_contains "card"
}

@test "react without --comment shows error" {
  run fizzy react "👍" --card 123
  assert_failure
  assert_output_contains "comment"
}

@test "react requires authentication" {
  run fizzy react "👍" --card 123 --comment abc456
  assert_failure
  assert_output_contains "Not authenticated"
}
