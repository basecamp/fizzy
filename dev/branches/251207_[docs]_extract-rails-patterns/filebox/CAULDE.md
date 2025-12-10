# Fizzy - Modern Rails Pattern Reference

This file provides guidance to AI coding agents and serves as a pattern index for this production-grade Rails application by 37signals.

## Application Overview

Fizzy is a collaborative kanban-style issue tracker. Teams create **boards**, organize work into **columns** (workflow stages), and manage **cards** (tasks/issues) with comments, mentions, assignments, and tags. Key differentiators: passwordless magic link auth, path-based multi-tenancy, automatic card "entropy" (stale work auto-postpones), and real-time collaboration via Turbo/ActionCable.

## Tech Stack

- **Rails 8** with Hotwire (Turbo + Stimulus)
- **SQLite/MySQL** with sharded full-text search
- **Solid Queue** for background jobs (no Redis)
- **Action Text** for rich text content
- **Action Cable** for real-time updates
- **UUIDv7** primary keys (base36 encoded)
- **Importmaps** (no Node.js build step)
- **Kamal** for deployment

---

## Pattern Index

Each pattern below links to detailed documentation in `dev/patterns/`. Use these as quick references when implementing similar functionality.

We first take a conversational approach ensuring we extract what's actually useful rather than
cargo-culting patterns. The current setup works well as a prompt scaffold:

- CLAUDE.md - Pattern index with placeholders (the tables and quick refs act as conversation
  starters)
- dev/patterns/README.md - Lists what we could extract, guides future sessions

When you're ready to dive into a specific pattern, just mention it and we can:
1. Discuss what makes it interesting/useful
2. Explore the actual implementation in Fizzy
3. Decide what's worth extracting vs. what's too Fizzy-specific
4. Write the description for CLAUDE.md and detailed extraction in dev/patterns/




### Authentication & Sessions

| Pattern                | Summary                                        | Detail                                                        |
|------------------------|------------------------------------------------|---------------------------------------------------------------|
| **Magic Link Auth**    | 6-char codes, 15-min expiry, consume-on-use    | [magic-link-auth.md](dev/patterns/magic-link-auth.md)         |
| **Session Management** | Database-backed sessions with signed cookies   | [sessions.md](dev/patterns/sessions.md)                       |
| **Identity vs User**   | Global identity (email) with per-account users | [identity-user-split.md](dev/patterns/identity-user-split.md) |

**Quick reference - MagicLink model:**
```ruby
class MagicLink < ApplicationRecord
  CODE_LENGTH = 6
  EXPIRATION_TIME = 15.minutes
  scope :active, -> { where(expires_at: Time.current...) }

  def self.consume(code)
    active.find_by(code: Code.sanitize(code))&.consume
  end
end
```

### Multi-Tenancy

| Pattern                       | Summary                                              | Detail                                                      |
|-------------------------------|------------------------------------------------------|-------------------------------------------------------------|
| **URL Path Tenancy**          | `/{account_id}/...` via middleware, no subdomains    | [url-path-tenancy.md](dev/patterns/url-path-tenancy.md)     |
| **Current Context**           | `Current.account`, `Current.user`, `Current.session` | [current-attributes.md](dev/patterns/current-attributes.md) |
| **Job Context Serialization** | Jobs capture/restore account context automatically   | [job-context.md](dev/patterns/job-context.md)               |

**Quick reference - Account slug middleware:**
```ruby
module AccountSlug
  PATTERN = /(\d{7,})/

  class Extractor
    def call(env)
      if request.path_info =~ /\A(\/#{PATTERN})/
        request.script_name = $1
        request.path_info = $'.empty? ? "/" : $'
        env["fizzy.external_account_id"] = $2.to_i
      end
      Current.with_account(Account.find_by(external_account_id: env["fizzy.external_account_id"])) { @app.call(env) }
    end
  end
end
```

### Controller Patterns

| Pattern                    | Summary                                                          | Detail                                                  |
|----------------------------|------------------------------------------------------------------|---------------------------------------------------------|
| **Authentication Concern** | `allow_unauthenticated_access`, `require_unauthenticated_access` | [auth-concern.md](dev/patterns/auth-concern.md)         |
| **Authorization Concern**  | Role-based access, board admin checks                            | [authorization.md](dev/patterns/authorization.md)       |
| **Resource Scoping**       | `BoardScoped`, `CardScoped` concerns for nested resources        | [resource-scoping.md](dev/patterns/resource-scoping.md) |
| **ETag Caching**           | Session-based etags for personalized caching                     | [etag-caching.md](dev/patterns/etag-caching.md)         |

**Quick reference - Authentication macros:**
```ruby
class SessionsController < ApplicationController
  allow_unauthenticated_access only: [:new, :create]
  require_unauthenticated_access only: [:new]
end
```

### Model Patterns

| Pattern           | Summary                                           | Detail                                            |
|-------------------|---------------------------------------------------|---------------------------------------------------|
| **Eventable**     | Polymorphic audit trail with `track_event`        | [eventable.md](dev/patterns/eventable.md)         |
| **Searchable**    | Sharded full-text search via denormalized records | [searchable.md](dev/patterns/searchable.md)       |
| **Notifiable**    | After-commit notification dispatch                | [notifiable.md](dev/patterns/notifiable.md)       |
| **Broadcastable** | Real-time updates via `broadcasts_refreshes`      | [broadcastable.md](dev/patterns/broadcastable.md) |
| **Mentions**      | @mention parsing and notification                 | [mentions.md](dev/patterns/mentions.md)           |
| **Taggable**      | Dynamic tag creation with case normalization      | [taggable.md](dev/patterns/taggable.md)           |
| **Assignable**    | Many-to-many with assigner tracking               | [assignable.md](dev/patterns/assignable.md)       |
| **Closeable**     | Status lifecycle with closure tracking            | [closeable.md](dev/patterns/closeable.md)         |
| **Watchable**     | Per-user subscription management                  | [watchable.md](dev/patterns/watchable.md)         |

**Quick reference - Eventable concern:**
```ruby
module Eventable
  extend ActiveSupport::Concern
  included { has_many :events, as: :eventable, dependent: :destroy }

  def track_event(action, creator: Current.user, board: self.board, **particulars)
    board.events.create!(action: "#{eventable_prefix}_#{action}", creator:, board:, eventable: self, particulars:)
  end
end
```

### View & Frontend Patterns

| Pattern                  | Summary                                       | Detail                                                      |
|--------------------------|-----------------------------------------------|-------------------------------------------------------------|
| **Application Layout**   | Header/main/footer with permanent frames      | [application-layout.md](dev/patterns/application-layout.md) |
| **Head Setup**           | View transitions, VAPID keys, morph refreshes | [head-setup.md](dev/patterns/head-setup.md)                 |
| **Turbo Frames**         | Isolated page regions with lazy loading       | [turbo-frames.md](dev/patterns/turbo-frames.md)             |
| **Turbo Streams**        | Broadcast templates for real-time UI          | [turbo-streams.md](dev/patterns/turbo-streams.md)           |
| **Stimulus Controllers** | Auto-save, dialogs, drag-drop, filters        | [stimulus-patterns.md](dev/patterns/stimulus-patterns.md)   |
| **Partial Organization** | Nested partials (display/preview/mini/perma)  | [partials.md](dev/patterns/partials.md)                     |

**Quick reference - Application layout structure:**
```erb
<body data-controller="local-time timezone-cookie turbo-navigation">
  <header><%= render "my/menu" if Current.user %></header>
  <%= render "layouts/shared/flash" %>
  <main><%= yield %></main>
  <footer>
    <div id="footer_frames" data-turbo-permanent="true">
      <%= render "bar/bar" %>
      <%= render "notifications/tray" %>
    </div>
  </footer>
</body>
```

### Background Jobs

| Pattern                   | Summary                                    | Detail                                                            |
|---------------------------|--------------------------------------------|-------------------------------------------------------------------|
| **Solid Queue Setup**     | Database-backed queues, no Redis           | [solid-queue.md](dev/patterns/solid-queue.md)                     |
| **Notification Bundling** | Time-windowed email aggregation            | [notification-bundling.md](dev/patterns/notification-bundling.md) |
| **Recurring Jobs**        | `config/recurring.yml` for scheduled tasks | [recurring-jobs.md](dev/patterns/recurring-jobs.md)               |

### Rich Text & Attachments

| Pattern                     | Summary                                 | Detail                                                      |
|-----------------------------|-----------------------------------------|-------------------------------------------------------------|
| **Action Text Setup**       | Rich text with embeds and mentions      | [action-text.md](dev/patterns/action-text.md)               |
| **Active Storage Variants** | Predefined image sizes with GIF support | [storage-variants.md](dev/patterns/storage-variants.md)     |

### Webhooks & Integrations

| Pattern                | Summary                                           | Detail                                                      |
|------------------------|---------------------------------------------------|-------------------------------------------------------------|
| **Webhook Delivery**   | State machine, HMAC signing, delinquency tracking | [webhooks.md](dev/patterns/webhooks.md)                     |
| **Push Notifications** | Web push via VAPID                                | [push-notifications.md](dev/patterns/push-notifications.md) |

### Infrastructure Patterns

| Pattern               | Summary                                     | Detail                                                  |
|-----------------------|---------------------------------------------|---------------------------------------------------------|
| **UUID Primary Keys** | UUIDv7 with base36 encoding, binary storage | [uuid-keys.md](dev/patterns/uuid-keys.md)               |
| **Sharded Search**    | 16-shard MySQL full-text via CRC32 hash     | [sharded-search.md](dev/patterns/sharded-search.md)     |
| **Rails Extensions**  | Custom date arithmetic, replica support     | [rails-extensions.md](dev/patterns/rails-extensions.md) |

### Domain-Specific Patterns

| Pattern               | Summary                                    | Detail                                              |
|-----------------------|--------------------------------------------|-----------------------------------------------------|
| **Entropy System**    | Auto-postpone stale cards after inactivity | [entropy.md](dev/patterns/entropy.md)               |
| **Board Publication** | Public sharing with secure tokens          | [publication.md](dev/patterns/publication.md)       |
| **Card Lifecycle**    | Draft → Published → Closed/Not Now         | [card-lifecycle.md](dev/patterns/card-lifecycle.md) |
| **Filter System**     | Composable scopes for complex queries      | [filters.md](dev/patterns/filters.md)               |

---

## Key Files Reference

| Area          | Primary Files                                                                       |
|---------------|-------------------------------------------------------------------------------------|
| Multi-tenancy | `config/initializers/tenanting/account_slug.rb`, `app/models/current.rb`            |
| Auth          | `app/controllers/concerns/authentication.rb`, `app/models/magic_link.rb`            |
| Events        | `app/models/eventable.rb`, `app/models/event.rb`                                    |
| Search        | `app/models/search/record.rb`, `app/models/concerns/searchable.rb`                  |
| Jobs          | `config/initializers/active_job.rb`, `app/jobs/application_job.rb`                  |
| Layout        | `app/views/layouts/application.html.erb`, `app/views/layouts/shared/_head.html.erb` |

---

## Development Commands

```bash
bin/setup              # Initial setup
bin/dev                # Start server (port 3006)
bin/rails test         # Run tests
bin/ci                 # Full CI suite
```

Dev URL: `http://fizzy.localhost:3006`
Login: `david@37signals.com` (magic link code appears in flash)

---

For agent-specific development guidance, see: @AGENTS.md
