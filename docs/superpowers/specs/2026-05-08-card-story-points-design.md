# Card Story Points — Design Spec
Date: 2026-05-08

## Summary

Add story points to cards in Dayzy. Anyone can assign a free numeric point value to any card. When a card is closed, the points are awarded to the assignee as a snapshot on the closure record. Reports will sum awarded points per user.

---

## Data Model

Two column additions to existing tables. Zero new models.

### Migration 1 — `cards.points`
```ruby
add_column :cards, :points, :integer
```
Stores the estimated point value for the card. Nullable — no points assigned means nil. Anyone can edit at any time while the card is open.

### Migration 2 — `closures.points_awarded`
```ruby
add_column :closures, :points_awarded, :integer
```
Snapshot of `card.points` at the moment the card is closed. Preserved permanently — editing card points after closing does not affect `points_awarded`. Nullable — cards closed with no points set have nil here.

### Earning logic
Points are awarded to the **assignee** on close. If a card has no assignee or no points, nothing is awarded (no error).

```ruby
# Card::Pointable#award_points_on_close
if points.present? && assignee.present?
  closure.update!(points_awarded: points)
end
```

### Reading earned points for reports
```ruby
Closure.joins(card: :assignments)
       .where(assignments: { assignee: user })
       .sum(:points_awarded)
```

---

## Concern — `Card::Pointable`

New file: `app/models/card/pointable.rb`

Included in `Card` alongside existing concerns (`Closeable`, `Assignable`, etc.).

Responsibilities:
- Exposes `award_points_on_close` method
- Called from inside `Card::Closeable#close` transaction (one line added)

No changes to `Cards::ClosuresController`. Award logic stays in the model layer per Dayzy's vanilla Rails philosophy.

---

## Controller & Routing

### Route
```ruby
# Inside the cards resource block
resource :points, only: [ :edit, :update ]
```

Produces:
```
GET  /:account_id/cards/:card_id/points/edit  →  edit  (inline form)
PUT  /:account_id/cards/:card_id/points       →  update (save)
```

### Controller
`app/controllers/cards/points_controller.rb`

- `edit` — renders inline edit form inside Turbo Frame
- `update` — saves `card.points`, re-renders points partial via Turbo Frame
- Uses existing `CardScoped` concern for `@card` lookup
- Blank/nil submission clears the points value (allows unsetting)

---

## Views

### Placement
Rendered inside `app/views/cards/display/perma/_tags.html.erb`, immediately after the tags list. Sits in the `card__header` row.

### Display states

| State | Appearance | Behaviour |
|---|---|---|
| Open, points set | `⬡ 5` (styled link) | Click → inline edit |
| Open, no points | `⬡ pts` (muted link) | Click → inline edit |
| Closed, points set | `⬡ 5` (plain text) | Not clickable |
| Closed, no points | Hidden | — |

### Turbo Frame
Both the display and edit states are wrapped in `turbo_frame_tag dom_id(card, :points)`. Clicking the display link loads the edit form in-place. Submitting the form saves and swaps back to display — no full page reload.

### Files
- `app/views/cards/points/_points.html.erb` — display partial
- `app/views/cards/points/edit.html.erb` — inline edit form
- `app/views/cards/display/perma/_tags.html.erb` — add one render line

---

## Constraints & Decisions

- **Free number** — any non-negative integer, no validation beyond that
- **Anyone can edit** — no role restriction, consistent with tags behaviour
- **Open cards only** — editing disabled once card is closed
- **Single assignee** — awards to current assignee at close time; if unassigned, points are not awarded (no error)
- **No event tracking** for point changes in this phase (can add later)
- **No negative points** — `min: 0` on the input field

---

## Out of Scope (this spec)

- User points leaderboard / profile totals UI (covered in Reports spec)
- Point history / audit log
- Team/board aggregate point views
- Notifications when points are awarded
