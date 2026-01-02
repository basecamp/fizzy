require "test_helper"

class CardLinkTest < ActiveSupport::TestCase
  setup do
    @card_a = cards(:logo)
    @card_b = cards(:layout)
    @card_c = cards(:text)
    @card_other_account = cards(:radio)
  end

  test "creates link between cards" do
    link = CardLink.create!(
      source_card: @card_a,
      target_card: @card_b,
      link_type: :parent
    )
    assert link.persisted?
    assert_equal @card_a.account, link.account
  end

  test "prevents self-linking" do
    link = CardLink.new(source_card: @card_a, target_card: @card_a, link_type: :related)
    assert_not link.valid?
    assert_includes link.errors[:target_card], "cannot link to itself"
  end

  test "prevents cross-account linking" do
    link = CardLink.new(source_card: @card_a, target_card: @card_other_account, link_type: :related)
    assert_not link.valid?
    assert_includes link.errors[:target_card], "must be in the same account"
  end

  test "prevents duplicate links of same type" do
    CardLink.create!(source_card: @card_a, target_card: @card_b, link_type: :related)
    duplicate = CardLink.new(source_card: @card_a, target_card: @card_b, link_type: :related)
    assert_not duplicate.valid?
  end

  test "allows same cards with different link types" do
    CardLink.create!(source_card: @card_a, target_card: @card_b, link_type: :related)
    parent_link = CardLink.new(source_card: @card_a, target_card: @card_b, link_type: :parent)
    assert parent_link.valid?
  end

  test "prevents simple circular parent chain" do
    # A is parent of B
    CardLink.create!(source_card: @card_a, target_card: @card_b, link_type: :parent)
    # B trying to be parent of A should fail
    link = CardLink.new(source_card: @card_b, target_card: @card_a, link_type: :parent)
    assert_not link.valid?
    assert_includes link.errors[:target_card], "would create circular parent chain"
  end

  test "prevents transitive circular parent chain" do
    # A → parent → B
    CardLink.create!(source_card: @card_a, target_card: @card_b, link_type: :parent)
    # B → parent → C
    CardLink.create!(source_card: @card_b, target_card: @card_c, link_type: :parent)
    # C → parent → A should fail (creates A→B→C→A cycle)
    link = CardLink.new(source_card: @card_c, target_card: @card_a, link_type: :parent)
    assert_not link.valid?
    assert_includes link.errors[:target_card], "would create circular parent chain"
  end

  test "allows circular related links" do
    # Related links can be circular - no hierarchy
    CardLink.create!(source_card: @card_a, target_card: @card_b, link_type: :related)
    reverse = CardLink.new(source_card: @card_b, target_card: @card_a, link_type: :related)
    assert reverse.valid?
  end

  test "cascade deletes when source card is destroyed" do
    link = CardLink.create!(source_card: @card_a, target_card: @card_b, link_type: :related)
    assert_difference -> { CardLink.count }, -1 do
      @card_a.destroy
    end
  end

  test "cascade deletes when target card is destroyed" do
    link = CardLink.create!(source_card: @card_a, target_card: @card_b, link_type: :related)
    assert_difference -> { CardLink.count }, -1 do
      @card_b.destroy
    end
  end
end

class CardLinkableTest < ActiveSupport::TestCase
  setup do
    @card_a = cards(:logo)
    @card_b = cards(:layout)
    @card_c = cards(:text)
  end

  test "parents returns parent cards as relation" do
    CardLink.create!(source_card: @card_a, target_card: @card_b, link_type: :parent)
    CardLink.create!(source_card: @card_a, target_card: @card_c, link_type: :parent)

    parents = @card_a.parents
    assert_kind_of ActiveRecord::Relation, parents
    assert_includes parents, @card_b
    assert_includes parents, @card_c
  end

  test "children returns child cards as relation" do
    CardLink.create!(source_card: @card_a, target_card: @card_b, link_type: :child)

    children = @card_a.children
    assert_kind_of ActiveRecord::Relation, children
    assert_includes children, @card_b
  end

  test "related_cards returns related cards as relation" do
    CardLink.create!(source_card: @card_a, target_card: @card_b, link_type: :related)

    related = @card_a.related_cards
    assert_kind_of ActiveRecord::Relation, related
    assert_includes related, @card_b
  end

  test "linked_cards returns all outgoing linked cards" do
    CardLink.create!(source_card: @card_a, target_card: @card_b, link_type: :parent)
    CardLink.create!(source_card: @card_a, target_card: @card_c, link_type: :related)

    linked = @card_a.linked_cards
    assert_includes linked, @card_b
    assert_includes linked, @card_c
  end

  test "linking_cards returns cards that link to this card" do
    CardLink.create!(source_card: @card_b, target_card: @card_a, link_type: :parent)

    linking = @card_a.linking_cards
    assert_includes linking, @card_b
  end

  test "has_links? returns true when card has outgoing links" do
    assert_not @card_a.has_links?
    CardLink.create!(source_card: @card_a, target_card: @card_b, link_type: :related)
    assert @card_a.has_links?
  end

  test "has_links? returns true when card has incoming links" do
    assert_not @card_a.has_links?
    CardLink.create!(source_card: @card_b, target_card: @card_a, link_type: :related)
    assert @card_a.has_links?
  end

  test "toggle_link adds link when none exists" do
    assert_difference -> { CardLink.count } do
      result = @card_a.toggle_link(@card_b, link_type: :related)
      assert_equal :added, result
    end
    assert @card_a.linked_cards.include?(@card_b)
  end

  test "toggle_link removes link when it exists" do
    @card_a.toggle_link(@card_b, link_type: :related)

    assert_difference -> { CardLink.count }, -1 do
      result = @card_a.toggle_link(@card_b, link_type: :related)
      assert_equal :removed, result
    end
    assert_not @card_a.linked_cards.include?(@card_b)
  end

  test "toggle_link with different types creates separate links" do
    @card_a.toggle_link(@card_b, link_type: :related)
    @card_a.toggle_link(@card_b, link_type: :parent)

    assert_equal 2, @card_a.outgoing_links.count
  end

  test "relations are chainable with other scopes" do
    CardLink.create!(source_card: @card_a, target_card: @card_b, link_type: :parent)
    CardLink.create!(source_card: @card_a, target_card: @card_c, link_type: :parent)

    # Can chain with where, order, etc.
    result = @card_a.parents.where(number: @card_b.number)
    assert_includes result, @card_b
    assert_not_includes result, @card_c
  end
end
