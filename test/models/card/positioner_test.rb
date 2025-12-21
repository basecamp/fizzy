require "test_helper"

class Card::PositionerTest < ActiveSupport::TestCase
  setup do
    @column = columns(:writebook_triage)
    @card_a = cards(:logo)
    @card_b = cards(:layout)
    @card_c = cards(:shipping)

    [ @card_a, @card_b, @card_c ].each do |card|
      card.update!(column: @column, status: "published")
    end
  end

  test "repositions a card between two neighbors" do
    @card_a.update!(position: 1024)
    @card_b.update!(position: 3072)
    @card_c.update!(position: 2048)

    positioner = Card::Positioner.new(
      relation: @column.cards.active,
      fallback_order: { last_active_at: :desc, id: :desc }
    )

    positioner.reposition!(card: @card_c, after_number: @card_a.number, before_number: @card_b.number)

    assert_equal 2048, @card_c.reload.position
  end

  test "repositions a card to the top when only before neighbor is provided" do
    @card_a.update!(position: 1024)
    @card_b.update!(position: 2048)

    positioner = Card::Positioner.new(
      relation: @column.cards.active,
      fallback_order: { last_active_at: :desc, id: :desc }
    )

    positioner.reposition!(card: @card_b, after_number: nil, before_number: @card_a.number)

    assert_equal 0, @card_b.reload.position
  end

  test "renumbers when there is no room between neighbors" do
    @card_a.update!(position: 1, last_active_at: 3.days.ago)
    @card_b.update!(position: 2, last_active_at: 2.days.ago)
    @card_c.update!(position: 3, last_active_at: 1.day.ago)

    positioner = Card::Positioner.new(
      relation: @column.cards.active,
      fallback_order: { last_active_at: :desc, id: :desc }
    )

    positioner.reposition!(card: @card_c, after_number: @card_a.number, before_number: @card_b.number)

    assert @card_c.reload.position.between?(@card_a.reload.position, @card_b.reload.position)
    assert_equal 1024, @card_a.reload.position
    assert_equal 2048, @card_b.reload.position
  end
end

