# Reports Page Sub-project 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-board reports page accessible via a button in the board header, showing all cards in a static HTML table.

**Architecture:** A standard Rails show action under `Boards::ReportsController` (following the `BoardScoped` concern pattern), a `link_to_report_board` helper mirroring `link_to_edit_board`, and a plain ERB table view — no Turbo Frames, no JavaScript.

**Tech Stack:** Rails 8, ERB, `BoardScoped` concern, `ActionDispatch::IntegrationTest`

---

## File Map

| Action | File |
|--------|------|
| Modify | `config/routes.rb` — add `resource :report, only: [:show]` inside `scope module: :boards` |
| Create | `app/controllers/boards/reports_controller.rb` — `show` action, loads all board cards |
| Modify | `app/helpers/boards_helper.rb` — add `link_to_report_board` helper |
| Modify | `app/views/boards/show.html.erb` — add report button to header |
| Create | `app/views/boards/reports/show.html.erb` — static card table |
| Create | `test/controllers/boards/reports_controller_test.rb` — controller tests |

---

### Task 1: Route + Controller

**Files:**
- Modify: `config/routes.rb:29-47`
- Create: `app/controllers/boards/reports_controller.rb`
- Create: `test/controllers/boards/reports_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/boards/reports_controller_test.rb`:

```ruby
require "test_helper"

class Boards::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
  end

  test "show returns success for board member" do
    get board_report_path(@board)
    assert_response :success
  end

  test "show assigns all board cards" do
    get board_report_path(@board)
    assert_equal 5, assigns(:cards).size
  end

  test "show requires board access" do
    logout_and_sign_in_as :david
    board = boards(:private)

    get board_report_path(board)
    assert_response :not_found
  end
end
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
bin/rails test test/controllers/boards/reports_controller_test.rb
```

Expected: FAIL — `NameError: undefined method 'board_report_path'`

- [ ] **Step 3: Add the route**

In `config/routes.rb`, inside the `scope module: :boards do` block (line 29), add `resource :report, only: [:show]` after `resource :entropy`:

```ruby
resources :boards do
  scope module: :boards do
    resources :accesses, only: :index
    resource :subscriptions
    resource :involvement
    resource :publication
    resource :entropy
    resource :report, only: [:show]     # ← add this line

    namespace :columns do
      # ...
    end
```

- [ ] **Step 4: Create the controller**

Create `app/controllers/boards/reports_controller.rb`:

```ruby
class Boards::ReportsController < ApplicationController
  include BoardScoped

  def show
    @cards = @board.cards.includes(:assignees, :closure, :tags, :not_now).order(created_at: :desc)
  end
end
```

- [ ] **Step 5: Create a minimal view so the action renders**

Create `app/views/boards/reports/show.html.erb` with placeholder content (full view in Task 3):

```erb
<p>Reports</p>
```

- [ ] **Step 6: Run the tests to confirm they pass**

```bash
bin/rails test test/controllers/boards/reports_controller_test.rb
```

Expected: 3 tests, 0 failures

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/boards/reports_controller.rb app/views/boards/reports/show.html.erb test/controllers/boards/reports_controller_test.rb
git commit -m "feat: add Boards::ReportsController with route and stub view"
```

---

### Task 2: Report View

**Files:**
- Modify: `app/views/boards/reports/show.html.erb` (replace stub from Task 1)

This task builds the full static HTML table. No new tests needed beyond what Task 1 covers — the controller test already asserts 200 and card count.

- [ ] **Step 1: Replace the stub view with the full table**

Replace the entire contents of `app/views/boards/reports/show.html.erb`:

```erb
<% @page_title = "#{@board.name} — Reports" %>

<%= content_for :header do %>
  <div class="header__actions header__actions--start hide-on-native">
  </div>

  <h1 class="header__title divider divider--fade full-width">
    <span class="overflow-ellipsis"><%= @board.name %> — Reports</span>
  </h1>

  <div class="header__actions header__actions--end hide-on-native">
    <%= link_to_edit_board @board %>
  </div>
<% end %>

<div class="container">
  <table class="reports-table">
    <thead>
      <tr>
        <th>#</th>
        <th>Title</th>
        <th>Status</th>
        <th>Assignees</th>
        <th>Points</th>
        <th>Created</th>
        <th>Closed</th>
      </tr>
    </thead>
    <tbody>
      <% @cards.each do |card| %>
        <tr>
          <td><%= card.number %></td>
          <td><%= link_to card.title, card_path(card) %></td>
          <td>
            <% if card.closed? %>
              Closed
            <% elsif card.postponed? %>
              Postponed
            <% else %>
              Open
            <% end %>
          </td>
          <td><%= card.assignees.map(&:name).join(", ") %></td>
          <td><%= card.points %></td>
          <td><%= card.created_at.to_date %></td>
          <td><%= card.closed_at&.to_date %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

- [ ] **Step 2: Verify the page renders in the browser**

Start the dev server (`bin/dev`) and visit:
`http://app.fizzy.localhost:3006/<account_id>/boards/<board_id>/report`

Expected: page loads showing "Writebook — Reports" heading and a table with card rows.

- [ ] **Step 3: Commit**

```bash
git add app/views/boards/reports/show.html.erb
git commit -m "feat: add reports page table view"
```

---

### Task 3: Board Header Button

**Files:**
- Modify: `app/helpers/boards_helper.rb`
- Modify: `app/views/boards/show.html.erb`

- [ ] **Step 1: Add the helper to boards_helper.rb**

Open `app/helpers/boards_helper.rb`. The file currently contains:

```ruby
module BoardsHelper
  def link_back_to_board(board, prefer_referrer: [])
    back_link_to board.name, board, "keydown.left@document->hotkey#click keydown.esc@document->hotkey#click click->turbo-navigation#backIfSamePath", prefer_referrer:
  end

  def link_to_edit_board(board)
    link_to edit_board_path(board), class: "btn btn--circle-mobile",
      data: { controller: "tooltip", bridge__overflow_menu_target: "item", bridge_title: "Board settings" } do
      icon_tag("settings") + tag.span("Settings for #{board.name}", class: "for-screen-reader")
    end
  end
end
```

Add `link_to_report_board` after `link_to_edit_board`:

```ruby
module BoardsHelper
  def link_back_to_board(board, prefer_referrer: [])
    back_link_to board.name, board, "keydown.left@document->hotkey#click keydown.esc@document->hotkey#click click->turbo-navigation#backIfSamePath", prefer_referrer:
  end

  def link_to_edit_board(board)
    link_to edit_board_path(board), class: "btn btn--circle-mobile",
      data: { controller: "tooltip", bridge__overflow_menu_target: "item", bridge_title: "Board settings" } do
      icon_tag("settings") + tag.span("Settings for #{board.name}", class: "for-screen-reader")
    end
  end

  def link_to_report_board(board)
    link_to board_report_path(board), class: "btn btn--circle-mobile",
      data: { controller: "tooltip", bridge__overflow_menu_target: "item", bridge_title: "Reports" } do
      icon_tag("activity") + tag.span("Reports for #{board.name}", class: "for-screen-reader")
    end
  end
end
```

- [ ] **Step 2: Write a failing test for the helper**

Add to `test/controllers/boards/reports_controller_test.rb` — add a new test:

```ruby
test "show page is linked from board header" do
  get board_path(@board)
  assert_select "a[href='#{board_report_path(@board)}']"
end
```

- [ ] **Step 3: Run the test to confirm it fails**

```bash
bin/rails test test/controllers/boards/reports_controller_test.rb -n "test_show_page_is_linked_from_board_header"
```

Expected: FAIL — assertion that link exists on board show page

- [ ] **Step 4: Add the button to the board show view**

Open `app/views/boards/show.html.erb`. The `header__actions--end` div currently contains only `link_to_edit_board`. Add `link_to_report_board` before it:

```erb
<div class="header__actions header__actions--end hide-on-native">
  <%= link_to_report_board @board %>
  <%= link_to_edit_board @board %>
</div>
```

- [ ] **Step 5: Run all reports tests**

```bash
bin/rails test test/controllers/boards/reports_controller_test.rb
```

Expected: 4 tests, 0 failures

- [ ] **Step 6: Run the full test suite to check for regressions**

```bash
bin/rails test
```

Expected: all tests pass

- [ ] **Step 7: Commit**

```bash
git add app/helpers/boards_helper.rb app/views/boards/show.html.erb test/controllers/boards/reports_controller_test.rb
git commit -m "feat: add report button to board header"
```
