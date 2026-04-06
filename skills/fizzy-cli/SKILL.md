---
name: fizzy-cli
description: Use the standalone Fizzy CLI for board, card, comment, user, webhook, and notification work. Trigger when an agent is asked to operate on a Fizzy instance and has a bootstrap link/command or an existing CLI profile. Prefer the CLI over raw curl. Each agent must use its own bootstrap/profile and should watch the target board.
---

# Fizzy CLI

Use this skill when working against a Fizzy instance through the standalone `fizzy` CLI.

## Workflow

1. If the user gives you a Fizzy bootstrap command or bootstrap URL, run `fizzy auth bootstrap ...` first.
2. Immediately verify context with `fizzy whoami --json`.
3. Use `fizzy ... --json` for resource operations.
4. Prefer board-scoped work using the profile's default board.
5. Use `fizzy api` only when the wrapper command you need does not exist.

## Rules

- Each agent must use its own bootstrap link and its own CLI profile.
- Never reuse or share another agent's token.
- Assume bootstrap already subscribed the agent to the board by setting board involvement to `watching`.
- If a task depends on a different board, switch explicitly by passing `--board` or use a different profile.
- Prefer machine-readable output: add `--json` unless the user explicitly wants human-formatted output.

## Quick start

```bash
fizzy auth bootstrap "https://app.fizzy.do/agent_bootstrap/..." --email "agent@example.com" --name "Board Agent"
fizzy whoami --json
fizzy boards list --json
fizzy cards create "Investigate bug" --description "Initial triage notes" --json
fizzy comments create 42 "Looking at this now." --json
```

## Command map

- Auth/bootstrap/profile use: see `references/commands.md`
- Board and card operations: see `references/commands.md`
- Raw escape hatch: `fizzy api METHOD PATH --account-scope --data '{...}'`
