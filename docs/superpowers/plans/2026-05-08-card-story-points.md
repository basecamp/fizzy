# Card Story Points Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add story points to Dayzy cards — a numeric value set by anyone, awarded to the assignee when the card is closed.

**Architecture:** Two column additions (cards.points, closures.points_awarded), a new Card::Pointable concern following Dayzy's existing concern pattern, a Cards::PointsController with edit/update, and Turbo Frame inline edit views placed next to the tags area.

**Tech Stack:** Ruby on Rails, Turbo Frames, Minitest, SQLite (dev)

---

### Task 1: Migrations

**Files:**
- Create: `db/migrate/TIMESTAMP_add_points_to_cards.rb`
- Create: `db/migrate/TIMESTAMP_add_points_awarded_to_closures.rb`

- [ ] **Step 1: Generate migration for cards.points**

```bash
bin/rails generate migration AddPointsToCards points:integer
```

Expected output: `db/migrate/TIMESTAMP_add_points_to_cards.rb` created.

- [ ] **Step 2: Generate migration for closures.points_awarded**

```bash
bin/rails generate migration AddPointsAwardedToClosures points_awarded:integer
```

Expected output: `db/migrate/TIMESTAMP_add_points_awarded_to_closures.rb` created.

- [ ] **Step 3: Run migrations**

```bash
bin/rails db:migrate
```

Expected output: Both migrations run with `== ... migrated` lines.

- [ ] **Step 4: Verify schema**

```bash
grep -A 2 "points" db/schema_sqlite.rb
```

Expected: `t.integer "points"` under cards table, `t.integer "points_awarded"` under closures table.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/ db/schema_sqlite.rb
git commit -m "Add points to cards and points_awarded to closures"
```

---

### Task 2: Card::Pointable concern + model wiring

**Files:**
- Create: `app/models/card/pointable.rb`
- Create: `test/models/card/pointable_test.rb`
- Modify: `app/models/card.rb` — add `Pointable` to includes list
- Modify: `app/models/card/closeable.rb` — call `award_points_on_close` in close transaction

- [ ] **Step 1: Write failing tests**

Create `test/models/card/pointable_test.rb`:

```ruby
require "test_helper"

class Card::PointableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "awards points to assignee on close" do
    card = cards(:logo)
    card.update!(points: 8)

    card.close(user: users(:david))

    assert_equal 8, card.closure.points_awarded
  end

  test "does not award points when card has no points" do
    card = cards(:logo)
    assert_nil card.points

    card.close(user: users(:david))

    assert_nil card.closure.points_awarded
  end

  test "does not award points when card has no assignee" do
    card = cards(:logo)
    card.assignments.delete_all
    card.update!(points: 5)

    card.close(user: users(:david))

    assert_nil card.closure.points_awarded
  end

  test "preserves points_awarded after card points are changed" do
    card = cards(:logo)
    card.update!(points: 8)
    card.close(user: users(:david))

    card.update!(points: 99)

    assert_equal 8, card.closure.reload.points_awarded
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/models/card/pointable_test.rb
```

Expected: Errors about `points` column not existing or `award_points_on_close` undefined.

- [ ] **Step 3: Create Card::Pointable concern**

Create `app/models/card/pointable.rb`:

```ruby
module Card::Pointable
  extend ActiveSupport::Concern

  def award_points_on_close
    if points.present? && assignees.any?
      closure.update!(points_awarded: points)
    end
  end
end
```

- [ ] **Step 4: Include Pointable in Card**

Open `app/models/card.rb`. Find the include line at the top:

```ruby
include Accessible, Assignable, Attachments, Broadcastable, Closeable, Colored, Commentable,
  Entropic, Eventable, Exportable, Golden, Mentions, Multistep, Pinnable, Postponable, Promptable,
  Readable, Searchable, Stallable, Statuses, Storage::Tracked, Taggable, Triageable, Watchable
```

Add `Pointable` alphabetically (after `Pinnable`, before `Postponable`):

```ruby
include Accessible, Assignable, Attachments, Broadcastable, Closeable, Colored, Commentable,
  Entropic, Eventable, Exportable, Golden, Mentions, Multistep, Pinnable, Pointable, Postponable, Promptable,
  Readable, Searchable, Stallable, Statuses, Storage::Tracked, Taggable, Triageable, Watchable
```

- [ ] **Step 5: Call award_points_on_close in Card::Closeable**

Open `app/models/card/closeable.rb`. Find the `close` method:

```ruby
def close(user: Current.user)
  unless closed?
    transaction do
      not_now&.destroy
      create_closure! user: user
      track_event :closed, creator: user
    end
  end
end
```

Add `award_points_on_close` after `create_closure!`:

```ruby
def close(user: Current.user)
  unless closed?
    transaction do
      not_now&.destroy
      create_closure! user: user
      award_points_on_close
      track_event :closed, creator: user
    end
  end
end
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
bin/rails test test/models/card/pointable_test.rb
```

Expected: 4 tests, 0 failures, 0 errors.

- [ ] **Step 7: Run full test suite to check for regressions**

```bash
bin/rails test test/models/card/closeable_test.rb
```

Expected: All existing closeable tests still pass.

- [ ] **Step 8: Commit**

```bash
git add app/models/card/pointable.rb app/models/card.rb app/models/card/closeable.rb test/models/card/pointable_test.rb
git commit -m "Add Card::Pointable concern with points award on close"
```

---

### Task 3: Routes + Cards::PointsController + tests

**Files:**
- Modify: `config/routes.rb` — add `resource :points` inside cards scope module block
- Create: `app/controllers/cards/points_controller.rb`
- Create: `test/controllers/cards/points_controller_test.rb`

- [ ] **Step 1: Write failing controller tests**

Create `test/controllers/cards/points_controller_test.rb`:

```ruby
require "test_helper"

class Cards::PointsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "edit" do
    get edit_card_points_path(cards(:logo))
    assert_response :success
  end

  test "update sets points" do
    patch card_points_path(cards(:logo)), params: { card: { points: 5 } }, as: :turbo_stream

    assert_response :success
    assert_equal 5, cards(:logo).reload.points
  end

  test "update clears points when blank" do
    cards(:logo).update!(points: 5)

    patch card_points_path(cards(:logo)), params: { card: { points: "" } }, as: :turbo_stream

    assert_response :success
    assert_nil cards(:logo).reload.points
  end

  test "update replaces points turbo frame" do
    patch card_points_path(cards(:logo)), params: { card: { points: 3 } }, as: :turbo_stream

    assert_response :success
    assert_includes response.body, dom_id(cards(:logo), :points)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/controllers/cards/points_controller_test.rb
```

Expected: Routing errors — `edit_card_points_path` undefined.

- [ ] **Step 3: Add route**

Open `config/routes.rb`. Find the `scope module: :cards` block inside `resources :cards`:

```ruby
resources :cards do
  scope module: :cards do
    resource :draft, only: :show
    resource :board
    resource :closure
    ...
  end
end
```

Add `resource :points, only: [ :edit, :update ]` in alphabetical order with the other resources:

```ruby
resource :pin
resource :points, only: [ :edit, :update ]
resource :publish
```

- [ ] **Step 4: Create controller**

Create `app/controllers/cards/points_controller.rb`:

```ruby
class Cards::PointsController < ApplicationController
  include CardScoped

  def edit
  end

  def update
    @card.update!(points: points_params)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          dom_id(@card, :points),
          partial: "cards/points/points",
          locals: { card: @card }
        )
      end
    end
  end

  private
    def points_params
      params.require(:card).permit(:points)[:points].presence
    end
end
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bin/rails test test/controllers/cards/points_controller_test.rb
```

Expected: 4 tests, 0 failures, 0 errors. (Views don't exist yet — tests may fail on missing template. If so, create empty view stubs and re-run.)

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/cards/points_controller.rb test/controllers/cards/points_controller_test.rb
git commit -m "Add Cards::PointsController with edit and update actions"
```

---

### Task 4: Views

**Files:**
- Create: `app/views/cards/points/_points.html.erb`
- Create: `app/views/cards/points/edit.html.erb`
- Modify: `app/views/cards/display/perma/_tags.html.erb` — add one render line

- [ ] **Step 1: Create the points display partial**

Create `app/views/cards/points/_points.html.erb`:

```erb
<%= turbo_frame_tag dom_id(card, :points) do %>
  <% if card.closed? %>
    <% if card.points.present? %>
      <span class="card__points">⬡ <%= card.points %></span>
    <% end %>
  <% else %>
    <%= link_to edit_card_points_path(card),
          class: "card__points btn btn--plain",
          data: { turbo_frame: dom_id(card, :points) } do %>
      ⬡ <%= card.points.present? ? card.points : "pts" %>
    <% end %>
  <% end %>
<% end %>
```

- [ ] **Step 2: Create the inline edit form**

Create `app/views/cards/points/edit.html.erb`:

```erb
<%= turbo_frame_tag dom_id(@card, :points) do %>
  <%= form_with url: card_points_path(@card), method: :patch,
        data: { turbo_frame: dom_id(@card, :points) } do |f| %>
    <%= f.number_field :points, value: @card.points,
          class: "card__points-input",
          placeholder: "pts",
          autofocus: true,
          min: 0,
          style: "width: 4rem;" %>
    <%= f.submit "✓", class: "btn btn--plain" %>
  <% end %>
<% end %>
```

- [ ] **Step 3: Add points render to tags partial**

Open `app/views/cards/display/perma/_tags.html.erb`. Find the closing `</div>` of the outer `card__tags` div. Add the render line just before it:

```erb
<div id="<%= dom_id(card, :tags) %>" class="card__tags">
  <div data-controller="dialog" ...>
    ...
  </div>

  <% if card.tags.any? %>
    <div class="card__tags-list min-width">
      ...
    </div>
  <% end %>

  <%= render "cards/points/points", card: card %>
</div>
```

- [ ] **Step 4: Run controller tests to confirm views work**

```bash
bin/rails test test/controllers/cards/points_controller_test.rb
```

Expected: 4 tests, 0 failures, 0 errors.

- [ ] **Step 5: Run full test suite**

```bash
bin/rails test
```

Expected: All tests pass. If any failures, fix before committing.

- [ ] **Step 6: Commit**

```bash
git add app/views/cards/points/ app/views/cards/display/perma/_tags.html.erb
git commit -m "Add story points display and inline edit views to card"
```
