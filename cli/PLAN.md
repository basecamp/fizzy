# Fizzy CLI (`fizzy`) - Agent-First Design

**fizzy** — the Fizzy CLI — a tool designed primarily for AI coding agents while remaining intuitive for humans. The name is the product name: direct, memorable, and easy to script.

> **Reference implementation**: `~/Work/basecamp/bcq` — port architecture, patterns, and test approach.
> **Dev server**: `http://fizzy.localhost:3006` — smoke testing target.

## Agent Compatibility

`fizzy` is designed to work with **any AI agent that can execute shell commands**:

| Agent | Integration Level | Notes |
|-------|-------------------|-------|
| **Claude Code** | Full | Hooks, skills, MCP (advanced features) |
| **OpenCode** | Full | CLI + JSON output |
| **Codex** | Full | CLI + JSON output |
| **Any shell-capable agent** | Full | Standard CLI interface |

**Philosophy**: The CLI is the universal foundation. Agent-specific enhancements (Claude Code hooks, skills, MCP) are optional layers on top. No agent is privileged over another for core functionality.

---

## Naming: `fizzy`


```bash
fizzy boards | jq '.data[0]'           # Extract from envelope
fizzy boards -q | jq '.[0]'            # Quiet mode: raw data
fizzy cards --assignee me --json       # Pipeline-friendly JSON
```

---

## Core Philosophy: Agent-First Design

### What Would an AI Agent Want?

1. **Instant orientation** — `fizzy` with no args → everything needed to start
2. **Predictable patterns** — Learn once, apply everywhere
3. **Rich context** — Equivalent to web UI, in agent-digestible form
4. **Token efficiency** — Dense output, no fluff
5. **Breadcrumbs** — "What can I do next?" after every action
6. **Error recovery** — Errors that help fix the problem
7. **ID/URL-based writes** — Unambiguous, explicit operations

### Output Philosophy

| Context | Format | Reason |
|---------|--------|--------|
| Piped / scripted | JSON envelope | Structured, with context and breadcrumbs |
| TTY / interactive | Markdown | Rich, readable, scannable |
| `--json` | JSON envelope | Force JSON output |
| `--md` | Markdown | Force Markdown output |
| `--quiet` / `--data` | Raw data only | Just `.data`, no envelope |

### JSON Output Contract

**Default (envelope):**
```bash
fizzy boards           # Returns envelope with data, summary, breadcrumbs
fizzy boards --json    # Forces JSON envelope even in TTY
```

**Quiet mode (data-only):**
```bash
fizzy boards --quiet   # Returns raw data array, no envelope
fizzy boards -q        # Same as --quiet
fizzy boards --data    # Alias for --quiet
```

**Piping examples:**
```bash
fizzy boards | jq '.data[0]'           # Extract from envelope
fizzy boards --quiet | jq '.[0]'       # Direct array access
fizzy boards -q | jq '.[] | .name'     # Iterate raw data
```

---

## S-Tier Outcome (Bar)

- Exhaustive coverage of public Fizzy API endpoints with parity checks
- Zero ambiguity on writes (IDs/URLs only) with clear, corrective errors
- High-confidence tests: happy paths, error paths, and output formats
- Agent ergonomics: consistent verbs, rich JSON envelopes, breadcrumbs
- Fast by default with resilient auth, retries, and rate-limit handling

### Quality Gates

Every task must pass before commit:
1. **Unit tests pass** — `bats test/*.bats`
2. **Smoke test pass** — Manual verification against `http://fizzy.localhost:3006`
3. **No regressions** — Existing tests continue to pass

Atomic commits: one logical change per commit, tests green before moving on.

## Layered Configuration

Configuration builds up from global → local, like git config:

```
~/.config/fizzy/
├── config.json           # Global defaults (all repos)
├── credentials.json      # OAuth tokens
├── client.json           # DCR client registration
└── accounts.json         # Discovered accounts

.fizzy/                # Per-directory/repo configuration
├── config.json           # Local overrides
└── cache/                # Local cache (optional)
```

### Config Hierarchy

```
Global (~/.config/fizzy/config.json)
  └─ Local (.fizzy/config.json)
       └─ Environment variables
            └─ Command-line flags
```

Each layer overrides the previous.

### Configuration Options

```json
// ~/.config/fizzy/config.json (global)
{
  "default_account_id": 12345,
  "output_format": "auto",      // auto | json | markdown
  "color": true,
  "pager": "less -R"
}

// .fizzy/config.json (per-directory)
{
  "board_id": 67890,
  "board_name": "Launch Board",     // For display
  "column_id": 11111,               // Default column
  "column_name": "In Progress",
  "team": ["@jeremy", "@david"]     // Quick @-mention completion
}
```

### Config Commands

```bash
fizzy config                         # Show effective config
fizzy config --global                # Show global only
fizzy config --local                 # Show local only

fizzy config init                    # Interactive: create .fizzy/config.json
fizzy config set board 67890            # Set locally
fizzy config set board 67890 --global   # Set globally
fizzy config unset board                # Remove local override

fizzy config board                      # Interactive board picker
fizzy config column                     # Interactive column picker
```

---

## Quick-Start Mode (No Arguments)

```
$ fizzy

fizzy v0.1.0 — Fizzy CLI
Auth: ✓ dev@example.com @ Acme

QUICK START
  fizzy boards              List boards
  fizzy cards               Your assigned cards
  fizzy search "query"      Find anything

COMMON TASKS
  fizzy card "title"        Create card
  fizzy triage <num> --to <col>  Triage card to column
  fizzy close <num>         Close card
  fizzy comment "text" --on <num>  Add comment

CONTEXT
  Account: Acme (897362094)
  Board: Fizzy 4 (67890)      ← from .fizzy/config.json
  Column: Development (11111)

NEXT: fizzy cards
```

### Fast Mode (No State Fetching)

Quick-start can optionally fetch live counts (cards assigned, unread messages, etc.), but this requires API calls and can be slow for agents:

```bash
fizzy                    # Default: no API calls, just orientation
fizzy --state            # Include live counts (requires API calls)
fizzy --fast             # Explicit: no state fetching (same as default)
```

The default prioritizes speed for agents. Use `--state` when you want live statistics.

---

## Response Structure

### Universal Envelope (JSON)

```json
{
  "ok": true,
  "data": [ ... ],
  "summary": "47 cards assigned to you",
  "context": {
    "account": {"id": 12345, "name": "Acme"},
    "board": {"id": 67890, "name": "Fizzy 4"},
    "column": {"id": 11111, "name": "Development"}
  },
  "breadcrumbs": [
    {"action": "create", "cmd": "fizzy card \"content\""},
    {"action": "filter", "cmd": "fizzy cards --status closed"},
    {"action": "search", "cmd": "fizzy search \"query\""}
  ],
  "meta": {
    "total": 47,
    "showing": 25,
    "page": 1,
    "next": "fizzy cards --page 2"
  }
}
```

### Markdown Mode

```markdown
## Your Cards (47)

| # | Content | Due | Assignee |
|---|---------|-----|----------|
| 123 | Fix login bug | Jan 15 | @jeremy |
| 124 | Update docs | Jan 20 | @david |

*Showing 25 of 47* — `fizzy cards --page 2` for more

### Actions
- Create: `fizzy card "content"`
- Close: `fizzy close <id>`
- Filter: `fizzy cards --status closed`
```

---

## Commands

### Query Commands (Read)

```bash
fizzy                                # Quick-start
fizzy boards                       # List boards
fizzy cards                          # Assigned cards (uses context)
fizzy cards --all                    # All cards in board
fizzy cards --in "Fizzy 4"        # In specific board
fizzy cards --column "In Progress"   # In specific column
fizzy search "query"                 # Global search
fizzy show card 123                  # Full card details
fizzy show board "Fizzy 4"      # Full board details
fizzy columns --in "Fizzy 4"         # List columns
fizzy people                         # List people
```

### Action Commands (Write)

**Write commands require explicit IDs or full Fizzy URLs. No name resolution for writes.**

```bash
fizzy card "Fix the login bug"                    # Create (uses context board/column)
fizzy card "Fix bug" --board 67890              # Create with explicit board ID
fizzy card "Fix bug" --board 67890 --column 11111 # Create with explicit column ID
fizzy close 123                                   # Close card by number
fizzy close 123 124 125                           # Close multiple
fizzy reopen 123                                  # Reopen by number
fizzy triage 123 --to 456                         # Triage to column ID
fizzy postpone 123                                # Move to "Not Now"
fizzy comment "LGTM" --on 123                     # Add comment by card number
fizzy assign 123 --to 456                         # Toggle assignment by person ID
fizzy gild 123                                    # Mark as golden
```

**Why ID-only for writes?**
- Prevents accidental writes to wrong resources
- Eliminates ambiguity errors during write operations
- Name resolution can fail; writes should be deterministic
- Agents should resolve names in read operations, then use IDs for writes

**Fizzy URLs work too:**
```bash
fizzy close http://fizzy.localhost:3006/1234567/boards/67890/cards/123
```

### Utility Commands

```bash
fizzy config                         # Show/set configuration
fizzy auth login                     # OAuth flow (browser)
fizzy auth login --no-browser        # OAuth flow (manual code entry)
fizzy auth logout                    # Clear credentials
fizzy auth status                    # Auth info
fizzy version                        # Version info
```

### Global Flags

```bash
--json, -j           # Force JSON envelope output
--md, -m             # Force Markdown output
--quiet, -q          # Raw data only (no envelope)
--data               # Alias for --quiet
--verbose, -v        # Debug output
--board, -b ID     # Override board context
--account, -a ID     # Override account
--help, -h           # Help
```

---

## Command → API Mapping

### API URL Structure

All API calls are scoped to an **account slug** (numeric external_account_id):

```
http://fizzy.localhost:3006/{account_slug}/boards
http://fizzy.localhost:3006/{account_slug}/cards
http://fizzy.localhost:3006/897362094/cards/123
```

The account slug is a 7+ digit numeric ID (e.g., `897362094`).

### Query Commands → API Endpoints

| Command | API Endpoint | Notes |
|---------|--------------|-------|
| `fizzy boards` | `GET /:slug/boards` | List accessible boards |
| `fizzy show board <id>` | `GET /:slug/boards/:id` | Board details |
| `fizzy columns --board <id>` | `GET /:slug/boards/:id/columns` | List columns |
| `fizzy cards` | `GET /:slug/cards` | List cards (with filters) |
| `fizzy cards --search "q"` | `GET /:slug/cards?terms[]=q` | Search via `terms[]` param |
| `fizzy show card <num>` | `GET /:slug/cards/:num` | Card details (includes steps) |
| `fizzy comments --on <num>` | `GET /:slug/cards/:num/comments` | List comments |
| `fizzy people` | `GET /:slug/users` | List users |
| `fizzy tags` | `GET /:slug/tags` | List tags |
| `fizzy notifications` | `GET /:slug/notifications` | List notifications |

### Action Commands → API Endpoints

| Command | API Endpoint | HTTP | Notes |
|---------|--------------|------|-------|
| `fizzy card "title"` | `/:slug/boards/:bid/cards` | POST | Create card |
| `fizzy close <num>` | `/:slug/cards/:num/closure` | POST | Close card |
| `fizzy reopen <num>` | `/:slug/cards/:num/closure` | DELETE | Reopen card |
| `fizzy triage <num> --to <col>` | `/:slug/cards/:num/triage` | POST | Move to column (`column_id` param) |
| `fizzy untriage <num>` | `/:slug/cards/:num/triage` | DELETE | Send back to triage |
| `fizzy postpone <num>` | `/:slug/cards/:num/not_now` | POST | Move to "Not Now" |
| `fizzy comment "text" --on <num>` | `/:slug/cards/:num/comments` | POST | Add comment |
| `fizzy assign <num> --to <uid>` | `/:slug/cards/:num/assignments` | POST | Toggle assignment |
| `fizzy tag <num> --with "name"` | `/:slug/cards/:num/taggings` | POST | Toggle tag |
| `fizzy watch <num>` | `/:slug/cards/:num/watch` | POST | Subscribe |
| `fizzy unwatch <num>` | `/:slug/cards/:num/watch` | DELETE | Unsubscribe |
| `fizzy gild <num>` | `/:slug/cards/:num/goldness` | POST | Mark golden |
| `fizzy ungild <num>` | `/:slug/cards/:num/goldness` | DELETE | Remove golden |
| `fizzy step "text" --on <num>` | `/:slug/cards/:num/steps` | POST | Add step |
| `fizzy react "👍" --on <cid>` | `/:slug/cards/:num/comments/:cid/reactions` | POST | Add reaction |

### Notification Commands → API Endpoints

| Command | API Endpoint | HTTP | Notes |
|---------|--------------|------|-------|
| `fizzy notifications` | `/:slug/notifications` | GET | List notifications |
| `fizzy notifications read <id>` | `/:slug/notifications/:id/reading` | POST | Mark as read |
| `fizzy notifications unread <id>` | `/:slug/notifications/:id/reading` | DELETE | Mark as unread |
| `fizzy notifications read --all` | `/:slug/notifications/bulk_reading` | POST | Mark all as read |

### Board Management Commands → API Endpoints

| Command | API Endpoint | HTTP | Notes |
|---------|--------------|------|-------|
| `fizzy board create "name"` | `/:slug/boards` | POST | Create board |
| `fizzy board update <id>` | `/:slug/boards/:id` | PUT | Update board |
| `fizzy board delete <id>` | `/:slug/boards/:id` | DELETE | Delete board |
| `fizzy board publish <id>` | `/:slug/boards/:id/publication` | POST | Publish publicly, returns `shareable_key` |
| `fizzy board unpublish <id>` | `/:slug/boards/:id/publication` | DELETE | Unpublish board |
| `fizzy board entropy <id> --days N` | `/:slug/boards/:id/entropy` | PUT | Set auto-postpone period |

### Column Management Commands → API Endpoints

| Command | API Endpoint | HTTP | Notes |
|---------|--------------|------|-------|
| `fizzy column create "name" --board <id>` | `/:slug/boards/:bid/columns` | POST | Create column |
| `fizzy column update <id>` | `/:slug/boards/:bid/columns/:id` | PUT | Update column |
| `fizzy column delete <id>` | `/:slug/boards/:bid/columns/:id` | DELETE | Delete column |
| `fizzy column left <id>` | `/:slug/boards/:bid/columns/:id/left_position` | POST | Move column left |
| `fizzy column right <id>` | `/:slug/boards/:bid/columns/:id/right_position` | POST | Move column right |

### Card Extended Commands → API Endpoints

| Command | API Endpoint | HTTP | Notes |
|---------|--------------|------|-------|
| `fizzy card publish <num>` | `/:slug/cards/:num/publish` | POST | Publish drafted card |
| `fizzy card move <num> --board <id>` | `/:slug/cards/:num/board` | PUT | Move card to another board |

### User Management Commands → API Endpoints

| Command | API Endpoint | HTTP | Notes |
|---------|--------------|------|-------|
| `fizzy user show <id>` | `/:slug/users/:id` | GET | Show user details |
| `fizzy user update <id>` | `/:slug/users/:id` | PUT | Update user |
| `fizzy user delete <id>` | `/:slug/users/:id` | DELETE | Deactivate user |
| `fizzy user role <id> --role admin` | `/:slug/users/:id/role` | PUT | Change user role |

### Account Management Commands → API Endpoints

| Command | API Endpoint | HTTP | Notes |
|---------|--------------|------|-------|
| `fizzy account show` | `/:slug/account/settings` | GET | Show account settings |
| `fizzy account update` | `/:slug/account/settings` | PUT | Update account name |
| `fizzy account entropy --days N` | `/:slug/account/entropy` | PUT | Set default auto-postpone |
| `fizzy account join-code` | `/:slug/account/join_code` | GET | Show join code |
| `fizzy account join-code reset` | `/:slug/account/join_code` | DELETE | Reset join code |
| `fizzy account export` | `/:slug/account/exports` | POST | Start data export |

### Webhook Commands → API Endpoints

| Command | API Endpoint | HTTP | Notes |
|---------|--------------|------|-------|
| `fizzy webhooks --board <id>` | `/:slug/boards/:bid/webhooks` | GET | List webhooks |
| `fizzy webhook show <id>` | `/:slug/boards/:bid/webhooks/:id` | GET | Show webhook |
| `fizzy webhook create --url <url>` | `/:slug/boards/:bid/webhooks` | POST | Create webhook |
| `fizzy webhook update <id>` | `/:slug/boards/:bid/webhooks/:id` | PUT | Update webhook |
| `fizzy webhook delete <id>` | `/:slug/boards/:bid/webhooks/:id` | DELETE | Delete webhook |

### Card Query Parameters (Filters)

The `GET /:slug/cards` endpoint supports rich filtering:

| Filter | Parameter | Example |
|--------|-----------|---------|
| By board | `board_ids[]` | `?board_ids[]=abc123` |
| By tag | `tag_ids[]` | `?tag_ids[]=xyz789` |
| By assignee | `assignee_ids[]` | `?assignee_ids[]=user1` |
| By creator | `creator_ids[]` | `?creator_ids[]=user2` |
| By status | `indexed_by` | `?indexed_by=closed` (values: `all`, `closed`, `not_now`, `stalled`, `postponing_soon`, `golden`) |
| By search | `terms[]` | `?terms[]=bug&terms[]=login` |
| Sort | `sorted_by` | `?sorted_by=newest` (values: `latest`, `newest`, `oldest`) |
| Assignment | `assignment_status` | `?assignment_status=unassigned` |
| Created date | `creation` | `?creation=thisweek` |
| Closed date | `closure` | `?closure=today` |

### Important: Card Numbers vs IDs

Cards have both:
- **`number`**: Sequential per-account (e.g., `1`, `2`, `123`) — used in URLs and display
- **`id`**: UUID (e.g., `03f5vaeq985jlvwv3arl4srq2`) — internal identifier

API endpoints use **card number** in URLs: `GET /:slug/cards/123` (not the UUID).

---

## Authentication

### OAuth 2.1 with Dynamic Client Registration

Fizzy implements **full OAuth 2.1** (verified in `config/routes.rb` and `app/controllers/oauth/`):

| Feature | Endpoint | Notes |
|---------|----------|-------|
| **Discovery** | `GET /.well-known/oauth-authorization-server` | RFC 8414 metadata |
| **DCR** | `POST /oauth/clients` | Dynamic client registration |
| **Authorization** | `GET /oauth/authorization/new` | Authorization code flow |
| **Token** | `POST /oauth/token` | Token exchange |
| **Revocation** | `POST /oauth/revocation` | Token revocation |

**OAuth Metadata** (from `Oauth::MetadataController`):
```json
{
  "issuer": "http://fizzy.localhost:3006",
  "authorization_endpoint": "http://fizzy.localhost:3006/oauth/authorization/new",
  "token_endpoint": "http://fizzy.localhost:3006/oauth/token",
  "registration_endpoint": "http://fizzy.localhost:3006/oauth/clients",
  "revocation_endpoint": "http://fizzy.localhost:3006/oauth/revocation",
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code"],
  "token_endpoint_auth_methods_supported": ["none"],
  "code_challenge_methods_supported": ["S256"],
  "scopes_supported": ["read", "write"]
}
```

**Key points**:
- Public clients only (`token_endpoint_auth_methods_supported: ["none"]`)
- PKCE required (`S256`)
- Two scopes: `read` (read-only), `write` (read+write)

### Auth Flow

```bash
# Standard flow (opens browser)
fizzy auth login

# Headless/remote flow (manual code entry)
fizzy auth login --no-browser
# Prints: Visit http://fizzy.localhost:3006/oauth/authorization/new?...
# Prints: Enter authorization code: [user pastes code]
```

### Alternative: Personal Access Tokens

For simple scripts, users can generate tokens manually:
1. Go to profile → API section → Personal access tokens
2. Generate token with `read` or `read+write` scope
3. Use via `FIZZY_TOKEN` environment variable

### Token File Security

Credentials stored at `~/.config/fizzy/credentials.json` with permissions `0600` (owner read/write only).

### Account Resolution

Account ID is required for all API calls. Resolution order:

1. `--account` flag
2. `FIZZY_ACCOUNT_ID` environment variable
3. `.fizzy/config.json` → `account_id`
4. `~/.config/fizzy/config.json` → `account_id`
5. Auto-discovered from token (if only one account)

**Fail fast with clear hints:**
```json
{
  "ok": false,
  "error": "No account configured",
  "code": "auth_required",
  "hint": "Run: fizzy auth login",
  "accounts": [
    {"id": 12345, "name": "37signals"},
    {"id": 67890, "name": "Side Board"}
  ]
}
```

---

## Name Resolution (Read Commands Only)

**Names are supported for read operations; write operations require IDs.**

```bash
# Read commands support names:
fizzy cards --in "Fizzy 4"        # By name
fizzy cards --in 67890               # By ID
fizzy show board "Fizzy 4"      # By name
fizzy people --search "@david"       # By @handle

# Write commands require IDs:
fizzy close 123                      # ID required
fizzy comment "Done!" --on 123       # ID required
fizzy assign 123 --to 456            # IDs required
```

### Workflow: Resolve Then Act

```bash
# Step 1: Find the resource (read, supports names)
fizzy show board "Fizzy 4" --quiet | jq '.id'
# → 67890

# Step 2: Act on it (write, requires ID)
fizzy card "Fix bug" --board 67890
```

### Ambiguous Name Handling

When a name matches multiple resources:
```json
{
  "ok": false,
  "error": "Ambiguous board name",
  "code": "ambiguous",
  "matches": [
    {"id": 67890, "name": "Fizzy 4"},
    {"id": 11111, "name": "Fizzy Classic"}
  ],
  "hint": "Use --board 67890 or more specific name"
}
```

---

## Rich Detail Views

```bash
$ fizzy show card 123 --md
```

```markdown
## Card #123: Fix the login bug

| Field | Value |
|-------|-------|
| Board | Fizzy 4 > Development |
| Status | Active |
| Assignee | @jeremy |
| Due | January 15, 2024 (in 5 days) |
| Created | January 10 by @david |

### Description
Login form throws 500 when email contains "+".

### Comments (2)
| When | Who | Comment |
|------|-----|---------|
| Jan 11 | @jeremy | On it, fix by EOD. |
| Jan 10 | @david | Can you look at this? |

### Actions
- `fizzy close 123` — Close
- `fizzy comment "text" --on 123` — Comment
- `fizzy assign 123 --to @name` — Reassign
```

---

## Error Design

### Helpful, Actionable Errors

```bash
$ fizzy show card 99999
```

```json
{
  "ok": false,
  "error": "Card not found",
  "code": "not_found",
  "searched": {"type": "card", "id": 99999},
  "suggestions": [
    {"id": 999, "content": "Fix header", "board": "Fizzy 4"},
    {"id": 9999, "content": "Update docs", "board": "Marketing"}
  ],
  "hint": "Try: fizzy search \"your keywords\""
}
```

### Error Codes

| Code | Exit | Meaning |
|------|------|---------|
| `success` | 0 | OK |
| `usage` | 1 | Bad arguments |
| `not_found` | 2 | Resource not found |
| `auth_required` | 3 | Need to login |
| `forbidden` | 4 | Permission denied |
| `rate_limit` | 5 | Too many requests |
| `network` | 6 | Connection failed |
| `api_error` | 7 | Server error |
| `ambiguous` | 8 | Multiple matches for name |

---

## Architecture

```
fizzy/cli/
├── bin/
│   └── fizzy                       # Entry point (~130 lines)
├── lib/
│   ├── core.sh                   # Output, formatting, utilities
│   ├── config.sh                 # 7-layer config management
│   ├── api.sh                    # HTTP client, caching, retries
│   ├── auth.sh                   # OAuth 2.1 + DCR + PKCE
│   ├── names.sh                  # Name → ID resolution
│   └── commands/
│       ├── quick_start.sh        # No-args orientation
│       ├── boards.sh             # boards, show board
│       ├── cards.sh              # cards, show card, card (create)
│       ├── actions.sh            # close, reopen, move, assign, etc.
│       ├── comments.sh           # comment, react
│       ├── search.sh             # search
│       ├── people.sh             # people
│       ├── config.sh             # config management
│       └── auth.sh               # auth login/logout/status
├── test/
│   ├── run.sh                    # Test runner
│   ├── helpers.sh                # Test utilities & assertions
│   ├── fixtures/                 # Mock API responses
│   └── *.bats                    # bats-core test files
├── completions/
│   ├── fizzy.bash
│   └── fizzy.zsh
└── docs/
    └── README.md
```

### Key bcq Patterns to Port

These patterns from bcq make it "S-Tier" — port them to fizzy:

#### 1. OAuth 2.1 Flow (`lib/auth.sh`)
```
_discover_oauth_config()  → Fetch /.well-known/oauth-authorization-server
_register_client()        → DCR to get client_id (stored in client.json)
_authorize()              → PKCE flow with code_verifier/challenge
_exchange_code()          → Token exchange, store in credentials.json
ensure_auth()             → Auto-refresh expired tokens
```

#### 2. 7-Layer Config (`lib/config.sh`)
```
1. /etc/fizzy/config.json         (system-wide)
2. ~/.config/fizzy/config.json    (user global)
3. <git-root>/.fizzy/config.json  (repo-level)
4. .fizzy/config.json             (current dir, walks up)
5. Environment: FIZZY_*
6. Flags: --account, --board
7. Global flags parsed early
```

#### 3. HTTP Client (`lib/api.sh`)
```
api_get(), api_post(), api_put(), api_delete()
├── ETag-based caching (If-None-Match → 304)
├── Exponential backoff (1s → 2s → 4s → 8s → 16s)
├── Rate limit handling (429 + Retry-After)
├── Token refresh on 401
└── Semantic error mapping (curl codes → exit codes)
```

#### 4. Output System (`lib/core.sh`)
```
output(data, summary, breadcrumbs, md_renderer)
├── Auto-detect TTY vs pipe
├── JSON envelope with context
├── Markdown for humans
└── --quiet for raw data
```

#### 5. Test Infrastructure (`test/`)
```
bats-core with:
├── setup/teardown (temp dirs, isolated home)
├── Assertions (assert_success, assert_json_value)
├── Fixtures (mock API responses)
└── Helpers (create_credentials, init_git_repo)
```

---

## Implementation Phases

Each phase must have passing tests before moving to the next.

### Phase 1: Foundation (Core Infrastructure)

**Goal**: Skeleton that can authenticate and make API calls.

- [ ] `bin/fizzy` — Entry point with command dispatch
- [ ] `lib/core.sh` — `output()`, `die()`, format detection
- [ ] `lib/config.sh` — 7-layer config loading
- [ ] `lib/api.sh` — `api_get()`, `api_post()`, caching, retries
- [ ] `lib/auth.sh` — OAuth 2.1 discovery, DCR, PKCE, token management
- [ ] `cmd_auth()` — login, logout, status subcommands
- [ ] Quick-start mode (no args → orientation)

**Tests**: `test/auth.bats`, `test/config.bats`, `test/core.bats`
**Smoke test**: `fizzy auth login` against dev server

### Phase 2: Core Queries

**Goal**: Read operations for boards, cards, users.

- [ ] `fizzy boards` — List boards
- [ ] `fizzy show board <id>` — Board details
- [ ] `fizzy columns --board <id>` — List columns
- [ ] `fizzy cards` — List with filters
- [ ] `fizzy show card <num>` — Card details with steps/comments
- [ ] `fizzy people` — List users
- [ ] `fizzy tags` — List tags

**Tests**: `test/boards.bats`, `test/cards.bats`, `test/people.bats`
**Smoke test**: All queries return valid JSON against dev server

### Phase 3: Core Actions

**Goal**: Write operations for cards.

- [ ] `fizzy card "title"` — Create card
- [ ] `fizzy close <num>` — Close card
- [ ] `fizzy reopen <num>` — Reopen card
- [ ] `fizzy triage <num> --to <col>` — Triage to column
- [ ] `fizzy untriage <num>` — Send back to triage
- [ ] `fizzy postpone <num>` — Move to Not Now
- [ ] `fizzy comment "text" --on <num>` — Add comment
- [ ] `fizzy assign <num> --to <uid>` — Toggle assignment
- [ ] `fizzy tag <num> --with "name"` — Toggle tag
- [ ] `fizzy watch <num>` / `unwatch` — Toggle subscription
- [ ] `fizzy gild <num>` / `ungild` — Toggle golden
- [ ] `fizzy step "text" --on <num>` — Add step
- [ ] `fizzy notifications` — List notifications
- [ ] `fizzy notifications read <id>` — Mark as read
- [ ] `fizzy notifications read --all` — Mark all as read

**Tests**: `test/actions.bats`, `test/comments.bats`, `test/notifications.bats`
**Smoke test**: Create → triage → close → reopen → comment flow

### Phase 4: Agent Ergonomics

**Goal**: Make it delightful for AI agents.

- [ ] Name resolution for read commands (boards, people)
- [ ] Breadcrumb generation in JSON envelope
- [ ] Error suggestions (similar cards, hint text)
- [ ] `fizzy config` — show/set/init
- [ ] Pagination handling

**Tests**: `test/names.bats`, `test/errors.bats`
**Smoke test**: Name resolution works, errors are helpful

### Phase 5: Polish

**Goal**: Production-ready.

- [ ] Tab completion (bash, zsh)
- [ ] Rate limiting + retry (429 handling)
- [ ] Comprehensive test coverage
- [ ] README documentation
- [ ] MCP server mode (`fizzy mcp serve`) — optional

---

## Test Requirements

### Test Categories

Every command must have:

1. **Happy path test** — Normal usage works
2. **Error path tests** — Proper error codes and messages
3. **Output format tests** — JSON and Markdown both correct
4. **Context tests** — Respects config hierarchy

### Test Infrastructure (from bcq)

```bash
# test/run.sh — Test runner
#!/usr/bin/env bash
bats test/*.bats

# test/helpers.sh — Shared test utilities
setup() {
  TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  mkdir -p "$XDG_CONFIG_HOME/fizzy"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# Custom assertions
assert_json_value() {
  local path="$1" expected="$2"
  actual=$(echo "$output" | jq -r "$path")
  [[ "$actual" == "$expected" ]] || fail "Expected $path to be '$expected', got '$actual'"
}

assert_exit_code() {
  [[ "$status" -eq "$1" ]] || fail "Expected exit code $1, got $status"
}
```

### Example Tests

```bash
# test/cards.bats

load helpers

@test "fizzy cards returns JSON envelope when piped" {
  run bash -c 'fizzy cards | jq -r .ok'
  assert_success
  assert_output 'true'
}

@test "fizzy cards returns raw array with --quiet" {
  run bash -c 'fizzy cards --quiet | jq -r type'
  assert_success
  assert_output 'array'
}

@test "fizzy cards respects .fizzy/config.json board" {
  mkdir -p .fizzy
  echo '{"board_id": "abc123"}' > .fizzy/config.json
  run fizzy cards --json
  assert_success
  assert_json_value '.context.board.id' 'abc123'
}

@test "fizzy card requires title" {
  run fizzy card
  assert_failure
  assert_exit_code 1
  assert_json_value '.code' 'usage'
}

@test "fizzy close requires card number" {
  run fizzy close
  assert_failure
  assert_exit_code 1
}

@test "fizzy auth status shows logged out when no credentials" {
  run fizzy auth status --json
  assert_success
  assert_json_value '.data.authenticated' 'false'
}
```

### Running Tests

```bash
# Run all tests
./test/run.sh

# Run specific test file
bats test/auth.bats

# Run with verbose output
bats --verbose-run test/cards.bats

# Run single test by name
bats test/cards.bats --filter "returns JSON envelope"
```

---

## Success Criteria

### Universal (All Agents)
1. **Agent orients in 1 command**: `fizzy` → knows what to do
2. **Task completion in 1-2 commands**: Create card, close card
3. **Error recovery**: Errors suggest fixes with actionable hints
4. **Web UI parity**: Detail views show everything humans see
5. **Token efficiency**: Dense output, no fluff
6. **Breadcrumbs**: Every response guides next action
7. **Config layering**: Global + local settings work correctly

### Agent-Specific Enhancements (Optional)
8. **Claude Code**: Hooks for commit linking, `/fizzy` skill
9. **MCP**: Structured tool definitions for advanced agents
10. **Future agents**: Extensible design accommodates new capabilities

---

## Interoperability Design

### Universal Interface (Required)
Every agent gets these capabilities via standard CLI:
- **JSON output**: `fizzy cards --json` → parseable data
- **Exit codes**: Semantic success/failure
- **Error format**: JSON errors with `code`, `hint`
- **Help text**: `fizzy --help`, `fizzy <cmd> --help`
- **Piping**: Works with jq, grep, xargs, etc.

### Claude Code Enhancements (Optional)
For Claude Code users who want deeper integration:
- **Hooks**: Auto-link commits to Fizzy cards
- **Skills**: `/fizzy` slash command with context awareness
- **MCP server**: Structured tools with rich schemas

### OpenCode / Codex / Others
These agents use the same CLI interface. As they add features (hooks, plugins, MCP), we can add support. The foundation is agent-agnostic.

---

## MCP Server: `fizzy mcp serve`

When MCP integration is compelling and delightful, `fizzy` itself can serve as an MCP server:

```bash
# Start MCP server on stdio (for local agents)
fizzy mcp serve

# Start MCP server on port (for remote agents)
fizzy mcp serve --port 8080

# Configure in .mcp.json
{
  "fizzy": {
    "command": "fizzy",
    "args": ["mcp", "serve"]
  }
}
```

**Why built-in?**
- Single tool to install and maintain
- CLI and MCP share the same code, auth, config
- No separate MCP server package to manage
- `fizzy` commands become MCP tools automatically

### Command Schema (Source of Truth)

Commands are defined in `lib/schema.json`, which drives:
1. CLI argument parsing and validation
2. CLI help text generation
3. MCP tool definitions

```json
// lib/schema.json
{
  "commands": {
    "cards": {
      "description": "List cards",
      "category": "query",
      "args": {
        "board": {
          "type": "integer",
          "aliases": ["-b", "--board", "--in"],
          "description": "Board ID"
        },
        "assignee": {
          "type": "string",
          "aliases": ["-a", "--assignee"],
          "description": "Filter by assignee (ID, @handle, or 'me')"
        },
        "status": {
          "type": "string",
          "enum": ["active", "closed"],
          "aliases": ["-s", "--status"],
          "description": "Filter by status"
        }
      }
    },
    "close": {
      "description": "Close card(s)",
      "category": "action",
      "args": {
        "id": {
          "type": "integer",
          "required": true,
          "positional": true,
          "variadic": true,
          "description": "Card ID(s) to close"
        }
      }
    }
  }
}
```

### MCP Output Mode

In MCP mode, all responses use the JSON envelope format:

```bash
fizzy mcp serve  # Forces --json for all tool responses
```

**When to use MCP vs CLI?**
| Scenario | CLI | MCP |
|----------|-----|-----|
| Quick queries | ✓ | |
| Piping/scripting | ✓ | |
| Structured tool calling | | ✓ |
| Rich type schemas | | ✓ |
| Resource subscriptions | | ✓ |
| Real-time updates | | ✓ |

The CLI remains the foundation. `fizzy mcp serve` is an adapter for MCP-native agents.

---

## Open Questions

Decisions to finalize before/during implementation:

### 1. Card Identifiers

Cards have both `number` (sequential, human-friendly) and `id` (UUID). The API uses `number` in URLs.

**Recommendation**: Use card numbers everywhere in CLI (matches web UI and API URLs).

### 2. Verb Naming

**DECIDED**: Use Fizzy's ubiquitous language (from domain models):

| CLI Command | Model Method | API Endpoint |
|-------------|--------------|--------------|
| `close` | `card.close` | POST /closure |
| `reopen` | `card.reopen` | DELETE /closure |
| `triage` | `card.triage_into(column)` | POST /triage |
| `postpone` | `card.postpone` | POST /not_now |
| `gild` | `card.gild` | POST /goldness |
| `ungild` | — | DELETE /goldness |

Source: `app/models/card/closeable.rb`, `triageable.rb`, `postponable.rb`, `golden.rb`

### 3. Search Interface

Options:
- `fizzy search "query"` — Dedicated search command
- `fizzy cards --search "query"` — Filter on cards command
- Both?

**Recommendation**: Support both. Search is common enough to warrant its own command.

### 4. Identity Endpoint

`GET /my/identity` returns accounts list. Use this for:
- Account discovery after OAuth
- Populating `accounts.json`
- `fizzy auth status` output

### 5. Notifications

**DECIDED**: Include in scope. Full API coverage is the goal.

Commands:
- `fizzy notifications` — List notifications
- `fizzy notifications read <id>` — Mark as read
- `fizzy notifications read --all` — Mark all as read

---

## References

- **Fizzy API docs**: `docs/API.md`
- **bcq reference**: `~/Work/basecamp/bcq/`
- **Dev server**: `http://fizzy.localhost:3006`
- **OAuth metadata**: `GET /.well-known/oauth-authorization-server`
