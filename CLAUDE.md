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

## Pattern Extraction Instructions

We first take a conversational approach ensuring we extract what's actually useful rather than
cargo-culting patterns. The current setup works well as a prompt scaffold:

- CLAUDE.md - Pattern index description a few paragraphs long, with placeholders (the tables and quick refs act as conversation
  starters)
- dev/patterns/README.md - Lists what we could extract, guides future sessions.

When you're ready to dive into a specific pattern, just mention it and we can:
1. Discuss what makes it interesting/useful
2. Explore the actual implementation in Fizzy
3. Decide what's worth extracting vs. what's too Fizzy-specific
4. Write a description in a few paragraphs for CLAUDE.md and detailed extraction in dev/patterns/

## Pattern Index

Each pattern below links to detailed documentation in `dev/patterns/`. Use these as quick references when implementing similar functionality.

### Identity & User Management

| Pattern                  | Summary                                                                           | Detail                                                                                |
|--------------------------|-----------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| **Identity/User Split**  | Global identity (auth) + per-account User (authz) enables multi-tenant membership | [identity-user-split.md](dev/patterns/identity-user-split.md)                         |
| **Role-Based Access**    | Owner → Admin → Member hierarchy with resource-level checks                       | [identity-user-split.md](dev/patterns/identity-user-split.md#userole-concern)         |
| **Board Access Control** | Explicit Access records with involvement levels (watching/access_only)            | [identity-user-split.md](dev/patterns/identity-user-split.md#access-model)            |
| **Current Context**      | Request-scoped resolution: Identity + Account → User                              | [identity-user-split.md](dev/patterns/identity-user-split.md#current-context)         |
| **URL Path Tenancy**     | `/{account_id}/...` middleware extracts and sets Current.account                  | [identity-user-split.md](dev/patterns/identity-user-split.md#account-slug-middleware) |

**Quick reference - Identity/User relationship:**
```ruby
# Identity: global person (email-based auth)
# User: account membership (per-tenant authz)
Identity (alice@example.com)
  └── User in Account A (role: owner)
  └── User in Account B (role: member)

# Current context auto-resolves the right User
Current.session = session         # sets identity
Current.account = account         # set by middleware
# → Current.user = identity.users.find_by(account: account)
```

**Quick reference - Joining an account:**
```ruby
identity = Identity.find_or_create_by!(email_address: "alice@example.com")
identity.join(account, role: :member, name: "Alice")
# → finds or creates User record for identity in account
```

### View & Layout

| Pattern                    | Summary                                                                         | Detail                                                    |
|----------------------------|---------------------------------------------------------------------------------|-----------------------------------------------------------|
| **Minimal Shell Layout**   | Layout provides zones + injection points; pages own their width/structure       | [layout-shell.md](dev/patterns/layout-shell.md)           |
| **Content Injection**      | `content_for` slots + instance variables for page-specific layout customization | [layout-shell.md](dev/patterns/layout-shell.md#injection) |
| **CSS-Driven Widths**      | `.panel` classes with `:has()` let pages control their container width          | [layout-shell.md](dev/patterns/layout-shell.md#widths)    |
| **User-Scoped CSS**        | Dynamic `<style>` block for visibility based on current user                    | [layout-shell.md](dev/patterns/layout-shell.md#user-css)  |

Fizzy's layout is a minimal shell that provides page zones (header, main, footer) and injection points, but delegates width constraints and content structure to individual pages. This avoids layout proliferation (`narrow.html.erb`, `wide.html.erb`) by pushing those decisions to CSS classes in views.

**Layout structure:**
```erb
<%# application.html.erb - the shell %>
<body>
  <header class="header <%= @header_class %>">
    <%= render "my/menu" if Current.user %>
    <%= yield :header %>                    <%# page-specific header content %>
  </header>

  <%= render "layouts/shared/flash" %>

  <main id="main">
    <%= yield %>                            <%# main content - pages control their own width %>
  </main>

  <footer id="footer">
    <%= yield :footer %>
    <%= render "bar/bar" if Current.user %> <%# persistent UI with turbo-permanent %>
  </footer>
</body>
```

**Page injection points:**
- `@page_title` → document `<title>` via helper
- `@header_class` → modifier class on `<header>` element
- `@hide_footer_frames` / `@disable_view_transition` → boolean flags
- `yield :head` → page-specific meta tags (OG, social cards)
- `yield :header` → page-specific header content (back links, title, actions)
- `yield :footer` → page-specific footer content

**Width control via CSS classes (not layout variants):**
```erb
<%# sessions/new.html.erb - narrow centered form %>
<div class="panel panel--centered">
  <%# content... %>
</div>

<%# account/settings/show.html.erb - medium width panels %>
<section class="settings">
  <div class="panel shadow center">...</div>
</section>

<%# boards/show.html.erb - full width, no panel wrapper %>
<%= render "boards/show/columns" %>
```

**The `.panel--centered` trick uses `:has()` to modify its parent:**
```css
.panel--centered {
  --panel-size: 42ch;

  #main:has(&) {
    display: grid;
    justify-content: center;
  }
}
```

**User-scoped CSS for visibility control:**
```erb
<%# _user_css.html.erb - injected in <head> %>
<style>
  [data-creator-id="<%= Current.user.id %>"] {
    [data-only-visible-to-others] { display: none; }
  }
  [data-creator-id]:not([data-creator-id="<%= Current.user.id %>"]) {
    [data-only-visible-to-you] { display: none; }
  }
</style>
```
This enables "Only visible to you" badges without JavaScript - views mark elements with data attributes, CSS handles visibility.
