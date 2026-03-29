# Fizzy CLI Commands

## Bootstrap and profiles

```bash
fizzy auth bootstrap "<bootstrap_url>" --email "agent@example.com" --name "Board Agent"
fizzy auth profiles --json
fizzy auth use my-profile
fizzy whoami --json
fizzy accounts list --json
```

## Boards and columns

```bash
fizzy boards list --json
fizzy boards get <board_id> --json
fizzy boards create "New board" --json
fizzy boards update <board_id> --name "Renamed" --json
fizzy boards watch <board_id> --json
fizzy columns list <board_id> --json
fizzy columns create "In progress" --board <board_id> --json
```

## Cards, comments, and steps

```bash
fizzy cards list --json
fizzy cards get <card_number> --json
fizzy cards create "Fix login bug" --description "Repro and notes" --board <board_id> --json
fizzy cards update <card_number> --title "Fix auth bug" --json
fizzy cards move <card_number> --board <board_id> --json
fizzy cards close <card_number> --json
fizzy cards reopen <card_number> --json
fizzy cards postpone <card_number> --json
fizzy cards triage <card_number> --column <column_id> --json
fizzy cards watch <card_number> --json
fizzy cards assign <card_number> <user_id> --json
fizzy cards tag <card_number> bug --json
fizzy comments list <card_number> --json
fizzy comments create <card_number> "Starting on this." --json
fizzy steps create <card_number> "Write regression test" --json
```

## Users, notifications, and webhooks

```bash
fizzy users list --json
fizzy notifications list --json
fizzy notifications read-all --json
fizzy webhooks list <board_id> --json
fizzy webhooks create <board_id> "Campfire" "https://example.com/hook" --actions card_published,card_closed --json
```

## Raw API

```bash
fizzy api GET cards --account-scope --json
fizzy api POST boards --account-scope --data '{"name":"Experimental"}' --json
```
