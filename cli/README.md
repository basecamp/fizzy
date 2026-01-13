# fizzy

Fizzy CLI — an agent-first interface for the Fizzy API.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/basecamp/fizzy/main/cli/install.sh | bash
```

This installs to `~/.local/share/fizzy` and creates `~/.local/bin/fizzy`. Run again to update.

**Requirements:** `bash 4+`, `curl`, `jq`

### macOS

macOS ships with bash 3.2. Install modern bash first:

```bash
brew install bash jq
curl -fsSL https://raw.githubusercontent.com/basecamp/fizzy/main/cli/install.sh | bash
```

### Updating

Run the installer again to update to the latest version.

## Quick Start

```bash
# Authenticate (opens browser)
fizzy auth login

# Request read-only access (least-privilege)
fizzy auth login --scope read

# Headless mode (manual code entry)
fizzy auth login --no-browser

# Check auth status
fizzy auth status

# Orient yourself
fizzy

# List boards
fizzy boards

# List cards on a board
fizzy cards --in "My Board"

# Show card details
fizzy show 42

# Create a card
fizzy card "Fix the login bug" --in "My Board"

# Close a card
fizzy close 42

# Search cards
fizzy search "login bug"
```

## Output Contract

**Default**: JSON envelope when piped, markdown when TTY.

```bash
# JSON envelope (piped or --json)
fizzy boards | jq '.data[0]'

# Raw data only (--quiet or --data)
fizzy boards --quiet | jq '.[0]'

# Force markdown
fizzy --md boards
```

### JSON Envelope Structure

```json
{
  "ok": true,
  "data": [...],
  "summary": "5 boards",
  "breadcrumbs": [
    {"action": "show", "cmd": "fizzy show board <id>"}
  ]
}
```

## Commands

### Query Commands

| Command | Description |
|---------|-------------|
| `boards` | List boards in the account |
| `cards` | List or filter cards |
| `columns` | List columns on a board |
| `comments` | List comments on a card |
| `notifications` | List notifications |
| `people` | List users in account |
| `search` | Search cards |
| `show` | Show card or board details |
| `tags` | List tags |

### Action Commands

| Command | Description |
|---------|-------------|
| `card` | Create a new card |
| `close` | Close a card |
| `reopen` | Reopen a closed card |
| `triage` | Move card to a column |
| `untriage` | Move card back to triage |
| `postpone` | Move card to "not now" |
| `comment` | Add a comment to a card |
| `assign` | Assign a card to someone |
| `tag` | Add a tag to a card |
| `watch` | Subscribe to card notifications |
| `unwatch` | Unsubscribe from card |
| `gild` | Mark card as golden |
| `ungild` | Remove golden status |
| `step` | Add a step (checklist item) to a card |
| `react` | Add a reaction to a card or comment |

## Global Flags

| Flag | Description |
|------|-------------|
| `--json`, `-j` | Force JSON output |
| `--md`, `-m` | Force markdown output |
| `--quiet`, `-q` | Raw data only (no envelope) |
| `--verbose`, `-v` | Debug output |
| `--board`, `-b`, `--in` | Board ID or name |
| `--account`, `-a` | Account slug |

## Authentication

fizzy uses OAuth 2.1 with Dynamic Client Registration (DCR). On first login, it registers itself as an OAuth client and opens your browser for authorization.

**Scope options:**
- `write` (default): Read and write access to all resources
- `read`: Read-only access — cannot create, update, or delete

```bash
fizzy auth login              # Write access (default)
fizzy auth login --scope read # Read-only access
fizzy auth status             # Shows current scope
```

Fizzy issues long-lived tokens that don't expire, so you only need to re-authenticate if you explicitly logout or revoke your token.

## Configuration

```
~/.config/fizzy/
├── config.json        # Global defaults
├── credentials.json   # OAuth tokens (0600)
├── client.json        # DCR client registration
└── accounts.json      # Discovered accounts

.fizzy/
└── config.json        # Per-directory overrides
```

Config hierarchy: system → user → repo → local → environment → flags

### Common Configuration

```bash
# Set default board for a project directory
cd ~/projects/my-app
fizzy config set board_id abc123

# View all configuration
fizzy config list

# View config sources
fizzy config path
```

## Environment

Point `fizzy` at different Fizzy instances using `FIZZY_BASE_URL`:

```bash
# Production (default)
fizzy boards

# Local development
FIZZY_BASE_URL=http://fizzy.localhost:3006 fizzy auth login
```

OAuth endpoints are discovered automatically via `.well-known/oauth-authorization-server` (RFC 8414).

## Name Resolution

Commands accept names, not just IDs:

```bash
# By name
fizzy cards --in "Fizzy 4"
fizzy triage 42 --to "In Progress"
fizzy assign 42 --to "Jane Doe"
fizzy tag 42 --with "bug"

# By ID (always works)
fizzy cards --in abc123xyz
```

Name resolution is case-insensitive and supports partial matching. Ambiguous matches show suggestions.

## Tab Completion

```bash
# Bash (add to ~/.bashrc)
source ~/.local/share/fizzy/completions/fizzy.bash

# Zsh (add to ~/.zshrc)
fpath=(~/.local/share/fizzy/completions $fpath)
autoload -Uz compinit && compinit
```

Provides completion for commands, subcommands, and flags.

## Testing

```bash
./test/run.sh         # Run all tests
bats test/*.bats      # Alternative: run bats directly
```

Tests use [bats-core](https://github.com/bats-core/bats-core). Install with `apt install bats` or `brew install bats-core`.

## License

[MIT](LICENSE.md)
