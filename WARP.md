# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## What is Fizzy?

Fizzy is a collaborative Kanban-style project management and issue tracking application built by 37signals. Teams create and manage cards (tasks/issues) across boards, organize work into columns representing workflow stages, and collaborate via comments, mentions, and assignments.

## Development Commands

### Setup and Server
```bash
bin/setup              # Initial setup (installs gems, creates DB, loads schema)
bin/setup --reset      # Reset database and seed it
bin/dev                # Start development server (runs on port 3006)
```

**Development URL:** http://fizzy.localhost:3006  
**Login:** `david@37signals.com` (grab the verification code from the browser console to sign in)

### Testing
```bash
bin/rails test                          # Run unit tests (fast feedback loop)
bin/rails test test/path/to/file_test.rb  # Run single test file
bin/rails test:system                   # Run system tests (Capybara + Selenium)
bin/ci                                  # Run full CI suite

# For parallel test execution issues:
PARALLEL_WORKERS=1 bin/rails test
```

The CI pipeline (`bin/ci`) runs:
1. Rubocop (Ruby style)
2. Bundler audit (gem security)
3. Importmap audit
4. Brakeman (security scan)
5. Gitleaks audit
6. Application tests (SQLite or MySQL)
7. System tests

### Database
```bash
bin/rails db:fixtures:load   # Load fixture data
bin/rails db:migrate          # Run migrations
bin/rails db:reset            # Drop, create, and load schema

# Use MySQL instead of SQLite (default):
DATABASE_ADAPTER=mysql bin/setup --reset
DATABASE_ADAPTER=mysql bin/ci
```

### Other Commands
```bash
bin/rails dev:email          # Toggle letter_opener for email previews
bin/jobs                     # Manage Solid Queue jobs
bin/kamal deploy             # Deploy (requires 1Password CLI for secrets)

# Email previews available at:
http://fizzy.localhost:3006/rails/mailers
```

## Architecture Overview

### Multi-Tenancy (URL Path-Based)

Fizzy uses **URL path-based multi-tenancy** instead of subdomains or separate databases:

- Each Account (tenant) has a unique `external_account_id` (7+ digit number)
- URLs are prefixed: `/{account_id}/boards/...`
- The `AccountSlug::Extractor` middleware extracts the account ID from the URL path and sets `Current.account`
- The slug is moved from `PATH_INFO` to `SCRIPT_NAME`, making Rails think it's "mounted" at that path
- All models include `account_id` for data isolation
- Background jobs automatically serialize and restore account context via `FizzyActiveJobExtensions`

**Testing implications:** Integration and system tests set `default_url_options[:script_name]` to include the account ID prefix.

### Authentication & Authorization

**Passwordless magic link authentication:**
- `Identity` model is global (email-based) and can have `Users` in multiple Accounts
- `User` belongs to an Account and has roles: `owner`, `admin`, `member`, `system`
- Sessions are managed via signed cookies
- Controller concerns: `Authentication` (session management) and `Authorization` (access control)
- Board-level access control is handled via `Access` records

### Core Domain Models

**Account** → The tenant/organization
- Has users, boards, cards, tags, webhooks, columns
- Has entropy configuration for automatic card postponement
- Generates sequential card numbers via `cards_count` counter

**Identity** → Global user (email)
- Can have Users in multiple Accounts
- Session management tied to Identity

**User** → Account membership
- Belongs to Account and Identity
- Has role (owner/admin/member/system)
- Explicit Board access via `Access` records

**Board** → Primary organizational unit
- Has columns for workflow stages
- Can be "all access" or selective
- Can be published publicly with shareable key
- Includes special columns: "stream" (triage), "not now" (postponed), "closed"

**Card** → Main work item (task/issue)
- Sequential number within each Account (via `account.cards_count`)
- Rich text description (ActionText) and attachments
- Lifecycle: triage → columns → closed/not_now
- Automatically postpones after inactivity ("entropy")
- Many concerns: `Assignable`, `Closeable`, `Entropic`, `Eventable`, `Taggable`, `Watchable`, etc.

**Event** → Records all significant actions
- Polymorphic association to changed object
- Drives activity timeline, notifications, and webhooks
- Has JSON `particulars` field for action-specific data

**Column** → Workflow stage within a Board
- Belongs to Account and Board
- Can be positioned (has ordering)

### Entropy System

Cards automatically "postpone" (move to "not now") after a configured period of inactivity:
- Account-level default entropy period
- Board-level entropy override
- Prevents endless todo lists from accumulating
- Hourly background job (`config/recurring.yml`) auto-postpones stale cards

### UUID Primary Keys

All tables use **UUIDs** (UUIDv7 format, base36-encoded as 25-character strings):
- Custom fixture UUID generation maintains deterministic ordering for tests
- Fixtures are always "older" than runtime records, so `.first`/`.last` work correctly in tests
- See `test/test_helper.rb` `FixturesTestHelper` for the fixture UUID generation logic

### Background Jobs (Solid Queue)

Database-backed job queue (no Redis required):
- `FizzyActiveJobExtensions` prepended to ActiveJob
- Jobs automatically capture/restore `Current.account` context
- All jobs inherit from `ApplicationJob`
- Use `enqueue_after_transaction_commit = true` by default
- Monitored via Mission Control::Jobs

**Job naming convention:**
- Use suffix `_later` for methods that enqueue a job
- Use suffix `_now` for the synchronous method that the job calls

**Key recurring tasks** (via `config/recurring.yml`):
- Deliver bundled notifications (every 30 min)
- Auto-postpone stale cards (hourly)
- Cleanup jobs for expired links, deliveries

### Sharded Full-Text Search

16-shard MySQL full-text search instead of Elasticsearch:
- Shards determined by account ID hash (CRC32)
- Search records denormalized for performance
- Models in `app/models/search/`
- Indexes cards, comments, and other searchable content

## Coding Style (Key Patterns)

**Read `STYLE.md` for complete guidance.** Key patterns:

### Conditional Returns
Prefer expanded conditionals over guard clauses (unless the guard is at the very beginning and the method body is non-trivial):

```ruby
# Preferred
def todos_for_new_group
  if ids = params.require(:todolist)[:todo_ids]
    @bucket.recordings.todos.find(ids.split(","))
  else
    []
  end
end

# Acceptable (guard at the beginning, non-trivial body)
def after_recorded_as_commit(recording)
  return if recording.parent.was_created?

  if recording.was_created?
    broadcast_new_column(recording)
  else
    broadcast_column_change(recording)
  end
end
```

### Method Ordering
1. `class` methods
2. `public` methods (with `initialize` at the top)
3. `private` methods

Order methods vertically by invocation order (top-level methods call helpers below them).

### Visibility Modifiers
No newline under visibility modifiers; indent content under them:

```ruby
class SomeClass
  def some_method
    # ...
  end

  private
    def some_private_method_1
      # ...
    end

    def some_private_method_2
      # ...
    end
end
```

### CRUD Controllers
Model web endpoints as CRUD operations on resources (REST). Introduce new resources rather than custom actions:

```ruby
# Good
resources :cards do
  resource :closure  # POST /cards/:id/closure = close, DELETE = reopen
end

# Avoid
resources :cards do
  post :close
  post :reopen
end
```

### Controller and Model Interactions
Follow a **vanilla Rails** approach:
- Thin controllers invoke a rich domain model directly
- No service layer artifacts between controllers and models
- Plain Active Record operations are fine: `@card.comments.create!(comment_params)`
- For complex behavior, prefer intention-revealing model methods: `@card.gild`
- Services/form objects are acceptable when justified, but not treated as special: `Signup.new(email_address: email_address).create_identity`

### Background Jobs
Write shallow job classes that delegate logic to domain models:
- Suffix `_later` for methods that enqueue jobs
- Suffix `_now` for synchronous methods that jobs invoke
- Example: `event.relay_later` enqueues `Event::RelayJob`, which calls `event.relay_now`

### Bang Methods
Only use `!` for methods that have a counterpart without `!`. Don't use `!` merely to flag destructive actions.

## Testing

- Test fixtures use deterministic UUIDs that sort correctly
- `Current.account` is set to `accounts("37s")` in test setup
- Integration/system tests include account ID in `script_name` for URL prefixing
- Tests run in parallel by default (configure `PARALLEL_WORKERS` to disable)
- Use VCR for recording external API calls (see `test/test_helper.rb`)
- Use mocha for mocking, WebMock for HTTP stubbing
