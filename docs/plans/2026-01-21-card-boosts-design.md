# Card Boosts Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extend the Reaction model to support reactions on Cards (not just Comments), with a compact boost count on card previews and full reaction UI in the card detail footer.

**Architecture:** Make Reaction polymorphic with `reactable_type`/`reactable_id`. Create `Cards::ReactionsController` mirroring the existing comment reactions controller. Add views for card reactions in the footer, and a compact count display on card previews.

**Tech Stack:** Rails 8, Turbo, Stimulus, ERB views

---

## Task 1: Migration - Make Reaction Polymorphic

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_make_reactions_polymorphic.rb`

**Step 1: Generate and write the migration**

Run:
```bash
bin/rails generate migration MakeReactionsPolymorphic
```

Then edit the migration file:

```ruby
class MakeReactionsPolymorphic < ActiveRecord::Migration[8.0]
  def change
    add_column :reactions, :reactable_type, :string
    add_column :reactions, :reactable_id, :uuid

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE reactions SET reactable_type = 'Comment', reactable_id = comment_id
        SQL
      end
    end

    change_column_null :reactions, :reactable_type, false
    change_column_null :reactions, :reactable_id, false

    remove_column :reactions, :comment_id, :uuid

    add_index :reactions, [:reactable_type, :reactable_id]
  end
end
```

**Step 2: Run the migration**

Run: `bin/rails db:migrate`

**Step 3: Verify migration succeeded**

Run: `bin/rails runner "puts Reaction.column_names.inspect"`

Expected: Should include `reactable_type` and `reactable_id`, should NOT include `comment_id`

**Step 4: Commit**

```bash
git add db/migrate/*_make_reactions_polymorphic.rb db/schema.rb
git commit -m "Make Reaction polymorphic for card and comment reactions"
```

---

## Task 2: Update Reaction Model

**Files:**
- Modify: `app/models/reaction.rb`

**Step 1: Write the failing test**

Add to `test/models/reaction_test.rb`:

```ruby
test "reaction can belong to a card" do
  card = cards(:logo)
  reaction = card.reactions.create!(content: "🎉")

  assert_equal card, reaction.reactable
  assert_equal "Card", reaction.reactable_type
end

test "creating card reaction touches card last_active_at" do
  card = cards(:logo)
  original_last_active_at = card.last_active_at

  travel 1.minute do
    card.reactions.create!(content: "🚀")
  end

  assert_operator card.reload.last_active_at, :>, original_last_active_at
end
```

**Step 2: Run the test to verify it fails**

Run: `bin/rails test test/models/reaction_test.rb`

Expected: FAIL - Card doesn't have `reactions` association yet

**Step 3: Update the Reaction model**

Replace `app/models/reaction.rb`:

```ruby
class Reaction < ApplicationRecord
  belongs_to :account, default: -> { reactable.account }
  belongs_to :reactable, polymorphic: true, touch: true
  belongs_to :reacter, class_name: "User", default: -> { Current.user }

  scope :ordered, -> { order(:created_at) }

  after_create :register_card_activity

  delegate :all_emoji?, to: :content

  private
    def register_card_activity
      reactable.card.touch_last_active_at
    end
end
```

**Step 4: Run tests to verify they still fail (need Card association)**

Run: `bin/rails test test/models/reaction_test.rb`

Expected: FAIL - Card doesn't have `reactions` association

**Step 5: Commit model change**

```bash
git add app/models/reaction.rb test/models/reaction_test.rb
git commit -m "Update Reaction model to be polymorphic"
```

---

## Task 3: Update Comment Model

**Files:**
- Modify: `app/models/comment.rb`

**Step 1: Update Comment association**

In `app/models/comment.rb`, change line 7 from:

```ruby
has_many :reactions, -> { order(:created_at) }, dependent: :delete_all
```

to:

```ruby
has_many :reactions, -> { order(:created_at) }, as: :reactable, dependent: :delete_all
```

**Step 2: Run existing comment reaction tests**

Run: `bin/rails test test/controllers/cards/comments/reactions_controller_test.rb`

Expected: All tests PASS

**Step 3: Commit**

```bash
git add app/models/comment.rb
git commit -m "Update Comment reactions association for polymorphic"
```

---

## Task 4: Add Reactions to Card Model

**Files:**
- Modify: `app/models/card.rb`

**Step 1: Add reactions association to Card**

In `app/models/card.rb`, after the `has_many :comments` line (around line 10), add:

```ruby
has_many :reactions, -> { order(:created_at) }, as: :reactable, dependent: :delete_all
```

**Step 2: Run the model tests**

Run: `bin/rails test test/models/reaction_test.rb`

Expected: All tests PASS

**Step 3: Commit**

```bash
git add app/models/card.rb
git commit -m "Add reactions association to Card model"
```

---

## Task 5: Add Routes for Card Reactions

**Files:**
- Modify: `config/routes.rb`

**Step 1: Write failing test for routes**

Add to `test/controllers/cards/reactions_controller_test.rb` (new file):

```ruby
require "test_helper"

class Cards::ReactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
    @card = cards(:logo)
  end

  test "routes exist" do
    assert_routing({ path: "/5986089/cards/#{@card.number}/reactions", method: :get },
                   { controller: "cards/reactions", action: "index", account_id: "5986089", card_id: @card.number.to_s })
    assert_routing({ path: "/5986089/cards/#{@card.number}/reactions", method: :post },
                   { controller: "cards/reactions", action: "create", account_id: "5986089", card_id: @card.number.to_s })
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/cards/reactions_controller_test.rb`

Expected: FAIL - No route matches

**Step 3: Add routes**

In `config/routes.rb`, inside the `resources :cards` block (around line 93), add after `resources :taggings`:

```ruby
resources :reactions, module: :cards
```

So it looks like:

```ruby
resources :taggings

resources :reactions, module: :cards

resources :comments do
```

**Step 4: Run test to verify routes exist**

Run: `bin/rails test test/controllers/cards/reactions_controller_test.rb`

Expected: FAIL - Controller doesn't exist (but routes work)

**Step 5: Commit**

```bash
git add config/routes.rb test/controllers/cards/reactions_controller_test.rb
git commit -m "Add routes for card reactions"
```

---

## Task 6: Create Cards::ReactionsController

**Files:**
- Create: `app/controllers/cards/reactions_controller.rb`

**Step 1: Add controller tests**

Replace `test/controllers/cards/reactions_controller_test.rb`:

```ruby
require "test_helper"

class Cards::ReactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
    @card = cards(:logo)
  end

  test "index" do
    get card_reactions_path(@card)
    assert_response :success
  end

  test "create" do
    assert_difference -> { @card.reactions.count }, 1 do
      post card_reactions_path(@card, format: :turbo_stream), params: { reaction: { content: "🎉" } }
      assert_turbo_stream action: :replace, target: dom_id(@card, :reacting)
    end
  end

  test "destroy" do
    reaction = @card.reactions.create!(content: "👍")

    assert_difference -> { @card.reactions.count }, -1 do
      delete card_reaction_path(@card, reaction, format: :turbo_stream)
      assert_turbo_stream action: :remove, target: dom_id(reaction)
    end
  end

  test "non-owner cannot destroy reaction" do
    sign_in_as :kevin
    reaction = @card.reactions.create!(content: "👍", reacter: users(:david))

    assert_no_difference -> { @card.reactions.count } do
      delete card_reaction_path(@card, reaction, format: :turbo_stream)
      assert_response :forbidden
    end
  end

  test "create as JSON" do
    assert_difference -> { @card.reactions.count }, 1 do
      post card_reactions_path(@card), params: { reaction: { content: "👍" } }, as: :json
    end

    assert_response :created
  end

  test "destroy as JSON" do
    reaction = @card.reactions.create!(content: "👍")

    assert_difference -> { @card.reactions.count }, -1 do
      delete card_reaction_path(@card, reaction), as: :json
    end

    assert_response :no_content
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/cards/reactions_controller_test.rb`

Expected: FAIL - Controller doesn't exist

**Step 3: Create the controller**

Create `app/controllers/cards/reactions_controller.rb`:

```ruby
class Cards::ReactionsController < ApplicationController
  include CardScoped

  before_action :set_reaction, only: %i[ destroy ]
  before_action :ensure_permision_to_administer_reaction, only: %i[ destroy ]

  def index
  end

  def new
  end

  def create
    @reaction = @card.reactions.create!(params.expect(reaction: :content))

    respond_to do |format|
      format.turbo_stream
      format.json { head :created }
    end
  end

  def destroy
    @reaction.destroy

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private
    def set_reaction
      @reaction = @card.reactions.find(params[:id])
    end

    def ensure_permision_to_administer_reaction
      head :forbidden if Current.user != @reaction.reacter
    end
end
```

**Step 4: Run tests (will fail due to missing views)**

Run: `bin/rails test test/controllers/cards/reactions_controller_test.rb`

Expected: FAIL - Missing template

**Step 5: Commit controller**

```bash
git add app/controllers/cards/reactions_controller.rb test/controllers/cards/reactions_controller_test.rb
git commit -m "Add Cards::ReactionsController"
```

---

## Task 7: Create Card Reactions Views

**Files:**
- Create: `app/views/cards/reactions/_reactions.html.erb`
- Create: `app/views/cards/reactions/_reaction.html.erb`
- Create: `app/views/cards/reactions/_menu.html.erb`
- Create: `app/views/cards/reactions/index.html.erb`
- Create: `app/views/cards/reactions/new.html.erb`
- Create: `app/views/cards/reactions/create.turbo_stream.erb`
- Create: `app/views/cards/reactions/destroy.turbo_stream.erb`

**Step 1: Create the views directory**

Run: `mkdir -p app/views/cards/reactions`

**Step 2: Create `_reactions.html.erb`**

```erb
<%= turbo_frame_tag card, :reacting do %>
  <div class="reactions">
    <div id="<%= dom_id(card, :reactions) %>" class="reactions__list">
      <%= render partial: "cards/reactions/reaction", collection: card.reactions %>
    </div>

    <%= turbo_frame_tag card, :new_reaction do %>
      <%= link_to new_card_reaction_path(card), role: "button",
            class: "reactions__trigger btn btn--circle", action: "soft-keyboard#open",
            data: { turbo_frame: dom_id(card, :new_reaction), action: "dialog#close" } do %>
        <%= image_tag "boost-color.svg", aria: { hidden: true } %>
        <span class="for-screen-reader">Add your own reaction</span>
      <% end %>
    <% end %>
  </div>
<% end %>
```

**Step 3: Create `_reaction.html.erb`**

```erb
<div id="<%= dom_id(reaction) %>"
      class="reaction"
      data-controller="reaction-delete"
      data-reaction-delete-reacter-id-value="<%= reaction.reacter.id %>"
      data-reaction-delete-perform-class="reaction--deleting"
      data-reaction-delete-reveal-class="expanded"
      data-reaction-delete-deleteable-class="reaction--deleteable">
  <figure class="reaction__avatar margin-none flex-item-no-shrink">
    <%= avatar_tag reaction.reacter, aria: { label: "#{reaction.reacter.name} reacted #{reaction.content}" } %>
  </figure>

  <%= tag.span reaction.content, role: "button",
        class: [ "txt-small", { "txt-medium": reaction.all_emoji? } ],
        data: { action: "click->reaction-delete#reveal keydown.enter->reaction-delete#reveal:prevent", reaction_delete_target: "content" } %>

  <%= button_to card_reaction_path(reaction.reactable, reaction),
        method: :delete,
        class: "reaction__delete btn btn--negative flex-item-justify-end",
        data: { action: "reaction-delete#perform", reaction_delete_target: "button" } do %>
    <%= icon_tag "trash" %>
    <span class="for-screen-reader">Delete this reaction</span>
  <% end %>
</div>
```

**Step 4: Create `_menu.html.erb`**

```erb
<div class="reaction__menu" data-controller="dialog" data-action="keydown.esc->dialog#close:stop click@document->dialog#closeOnClickOutside">
  <button class="reaction__menu-btn btn btn--circle borderless" data-action="click->dialog#open:stop" type="button">
    <%= icon_tag "reaction" %>
  </button>

  <dialog class="reaction__popup popup panel fill-white shadow" data-dialog-target="dialog">
    <div class="reaction__emoji-list">
      <% EmojiHelper::REACTIONS.each do |character, title| %>
        <%= tag.button character, title: title, class: "reaction__emoji-btn btn btn--circle borderless hide-focus-ring", type: "button", data: { action: "reaction-emoji#insertEmoji dialog#close", emoji: character } %>
      <% end %>
    </div>
  </dialog>
</div>
```

**Step 5: Create `index.html.erb`**

```erb
<%= render "cards/reactions/reactions", card: @card %>
```

**Step 6: Create `new.html.erb`**

```erb
<%= turbo_frame_tag @card, :new_reaction do %>
  <%= form_with url: card_reactions_path(@card),
        class: "reaction reaction__form expanded",
        html: { aria: { label: "New reaction" } },
        data: { controller: "form reaction-emoji", turbo_frame: dom_id(@card, :reacting), action: "keydown.esc->form#cancel submit->form#preventEmptySubmit submit->form#preventComposingSubmit" } do |form| %>
    <label class="reaction__form-label flex gap" style="--column-gap: 0.4ch;">
      <figure class="reaction__avatar margin-none flex-item-no-shrink">
        <%= avatar_tag Current.user %>
      </figure>

      <%= form.text_field :content, autofocus: true, autocomplete: "off", autocorrect: "off", maxlength: 16,
            pattern: /\S+.*/, class: "input reaction__input txt-small", name: "reaction[content]", data: { form_target: "input", reaction_emoji_target: "input", action: "compositionstart->form#compositionStart compositionend->form#compositionEnd" }, aria: { label: "Add a reaction" } %>
    </label>

    <%= render "cards/reactions/menu", card: @card %>

    <%= form.button class: "reaction__submit-btn btn btn--circle borderless", type: "submit", data: { form_target: "submit" } do %>
      <%= icon_tag "check-circle" %> <span class="for-screen-reader">Submit</span>
    <% end %>

    <%= link_to card_reactions_path(@card), role: "button",
          data: { turbo_frame: dom_id(@card, :reacting), form_target: "cancel" }, class: "reaction__cancel-btn btn btn--circle borderless" do %>
      <%= icon_tag "close-circle" %> <span class="for-screen-reader">Cancel</span>
    <% end %>
  <% end %>
<% end %>
```

**Step 7: Create `create.turbo_stream.erb`**

```erb
<%= turbo_stream.replace([ @card, :reacting ]) do %>
  <%= render "cards/reactions/reactions", card: @card.reload %>
<% end %>
```

**Step 8: Create `destroy.turbo_stream.erb`**

```erb
<%= turbo_stream.remove @reaction %>
```

**Step 9: Run controller tests**

Run: `bin/rails test test/controllers/cards/reactions_controller_test.rb`

Expected: All tests PASS

**Step 10: Commit**

```bash
git add app/views/cards/reactions/
git commit -m "Add card reactions views"
```

---

## Task 8: Add Reactions UI to Card Detail Footer

**Files:**
- Modify: `app/views/cards/container/footer/_published.html.erb`

**Step 1: Add reactions to footer**

Replace `app/views/cards/container/footer/_published.html.erb`:

```erb
<%# FIXME: Let's move this aside outside of the card container section so these frames don't reload/flicker when card is replaced %>
<div class="card-perma__actions card-perma__actions--left">
  <%= render "cards/reactions/reactions", card: card %>
</div>

<div class="card-perma__actions card-perma__actions--right">
  <%= turbo_frame_tag card, :watch, src: card_watch_path(card), target: "_top", refresh: :morph do %>
    <%= button_to card_watch_path(card), class: "btn", data: { controller: "tooltip" } do %>
      <%= icon_tag "bell-off" %> <span class="for-screen-reader">Watch this</span>
    <% end %>
  <% end %>
  <%= turbo_frame_tag card, :pin, src: card_pin_path(card), refresh: :morph do %>
    <%= button_to card_pin_path(card), class: "btn", data: { controller: "tooltip" } do %>
      <%= icon_tag "unpinned" %> <span class="for-screen-reader">Pin this card</span>
    <% end %>
  <% end %>
</div>

<%= render "cards/container/closure", card: card %>
```

**Step 2: Manually test in browser**

Run: `bin/dev`

Visit a card detail page and verify the reactions UI appears in the footer.

**Step 3: Commit**

```bash
git add app/views/cards/container/footer/_published.html.erb
git commit -m "Add reactions UI to card detail footer"
```

---

## Task 9: Add Boost Count to Card Preview

**Files:**
- Create: `app/views/cards/display/preview/_reactions.html.erb`
- Modify: `app/views/cards/display/_preview.html.erb`

**Step 1: Create the preview reactions partial**

Create `app/views/cards/display/preview/_reactions.html.erb`:

```erb
<% if card.reactions.any? %>
  <div class="card__reactions align-center gap-half flex-item-justify-end flex-item-no-shrink">
    <%= image_tag "boost-color.svg", aria: { hidden: true }, class: "card__reactions-icon" %>
    <strong><%= card.reactions.size %></strong>
  </div>
<% end %>
```

**Step 2: Add to card preview footer**

In `app/views/cards/display/_preview.html.erb`, modify the footer section (lines 47-51) to add the reactions partial. Change from:

```erb
  <footer class="card__footer flex gap-half">
    <%= render "cards/display/preview/meta", card: card, preview: true %>
    <%= render "cards/display/preview/comments", card: card %>
    <%= render "cards/display/common/background", card: card %>
  </footer>
```

to:

```erb
  <footer class="card__footer flex gap-half">
    <%= render "cards/display/preview/meta", card: card, preview: true %>
    <%= render "cards/display/preview/reactions", card: card %>
    <%= render "cards/display/preview/comments", card: card %>
    <%= render "cards/display/common/background", card: card %>
  </footer>
```

**Step 3: Manually test in browser**

Visit a board page, add a reaction to a card in detail view, then verify the count appears on the card preview.

**Step 4: Commit**

```bash
git add app/views/cards/display/preview/_reactions.html.erb app/views/cards/display/_preview.html.erb
git commit -m "Add boost count to card preview"
```

---

## Task 10: Add Fixtures for Card Reactions

**Files:**
- Modify: `test/fixtures/reactions.yml`

**Step 1: Add card reaction fixtures**

Add to `test/fixtures/reactions.yml`:

```yaml
card_reaction_david:
  id: <%= ActiveRecord::FixtureSet.identify("card_reaction_david", :uuid) %>
  account: 37s_uuid
  content: "🚀"
  reactable_type: Card
  reactable_id: <%= ActiveRecord::FixtureSet.identify("logo", :uuid) %>
  reacter: david_uuid

card_reaction_kevin:
  id: <%= ActiveRecord::FixtureSet.identify("card_reaction_kevin", :uuid) %>
  account: 37s_uuid
  content: "👍"
  reactable_type: Card
  reactable_id: <%= ActiveRecord::FixtureSet.identify("logo", :uuid) %>
  reacter: kevin_uuid
```

Also update existing fixtures to include `reactable_type`:

```yaml
kevin:
  id: <%= ActiveRecord::FixtureSet.identify("kevin_reaction", :uuid) %>
  account: 37s_uuid
  content: "👍"
  reactable_type: Comment
  reactable_id: <%= ActiveRecord::FixtureSet.identify("logo_agreement_jz", :uuid) %>
  reacter: kevin_uuid

david:
  id: <%= ActiveRecord::FixtureSet.identify("david_reaction", :uuid) %>
  account: 37s_uuid
  content: "👍"
  reactable_type: Comment
  reactable_id: <%= ActiveRecord::FixtureSet.identify("logo_agreement_jz", :uuid) %>
  reacter: david_uuid
```

**Step 2: Run all tests**

Run: `bin/rails test`

Expected: All tests PASS

**Step 3: Commit**

```bash
git add test/fixtures/reactions.yml
git commit -m "Add card reaction fixtures"
```

---

## Task 11: Run Full Test Suite

**Step 1: Run full CI suite**

Run: `bin/ci`

Expected: All checks PASS

**Step 2: Fix any issues**

If any tests fail, fix them and commit.

---

## Task 12: Style Card Reactions (if needed)

Work with the user to adjust styling for the card reactions in both the detail footer and preview. May need to add CSS for:

- `.card__reactions` - container on preview
- `.card__reactions-icon` - boost icon sizing
- Positioning of reactions in footer

This will be an iterative process based on visual feedback.
