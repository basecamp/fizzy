# Reports Page — Sub-project 1: Route, Controller, Board Entry Button

## Goal

Add a per-board reports page accessible from the board header, showing all cards (all statuses) in a simple table.

## Scope

This is Sub-project 1 of 4. It covers only the route, controller, board entry button, and a static card table view. Filters, KPIs, aggregations, and xlsx export are deferred to Sub-projects 2–4.

---

## Architecture

### Routing

Add `resource :report, only: [:show]` inside the existing `scope module: :boards` block in `config/routes.rb`.

Produces:
- `GET /boards/:board_id/report` → `Boards::ReportsController#show`
- Named helper: `board_report_path(@board)`

### Controller

**File:** `app/controllers/boards/reports_controller.rb`

```ruby
class Boards::ReportsController < ApplicationController
  include BoardScoped

  def show
    @cards = @board.cards.includes(:assignees, :closure, :tags).order(created_at: :desc)
  end
end
```

- `BoardScoped` handles `@board` lookup and authorization (board access check).
- All cards included regardless of status: open, closed, postponed, not_now.
- `includes` covers assignees, closure (for closed_at + points_awarded), and tags to avoid N+1 queries.

### Board Header Button

**Helper:** `link_to_report_board(board)` added to `app/helpers/boards_helper.rb`.

```ruby
def link_to_report_board(board)
  link_to board_report_path(board),
    class: "btn btn--circle-mobile",
    title: "Reports",
    data: { controller: "tooltip" } do
    icon_tag "bar-chart-2"
  end
end
```

Mirrors `link_to_edit_board` exactly. Rendered in the board header partial alongside the settings button, guarded by the same board-member visibility check.

### Report View

**File:** `app/views/boards/reports/show.html.erb`

Uses `content_for :header` to populate the board header area (board name + button strip). Renders a `<table>` with columns:

| # | Title | Status | Assignees | Points | Created | Closed |

- Status derived from card state: open columns → "Open", closed → "Closed", not_now → "Not Now", postponed → "Postponed"
- Points: `card.points` (blank if nil)
- Closed: `card.closure&.created_at` formatted as date
- No JavaScript required — pure server-rendered HTML

---

## Data Flow

1. User clicks bar-chart button in board header
2. Browser navigates to `/boards/:board_id/report`
3. `Boards::ReportsController#show` loads board via `BoardScoped`, fetches all cards with eager loads
4. `show.html.erb` renders static HTML table
5. No Turbo Frames, no async — straightforward page render

---

## Testing

- Unit: `Boards::ReportsController` — assert 200 for board member, 403/redirect for non-member, correct card count in assigns
- System: visit board, click report button, assert table renders with correct card rows

---

## What This Does Not Include

- Filtering by status, assignee, date range (Sub-project 2)
- KPI summary cards: total points, avg velocity, open/closed counts (Sub-project 2)
- Activity timeline (Sub-project 3)
- xlsx export (Sub-project 4)
