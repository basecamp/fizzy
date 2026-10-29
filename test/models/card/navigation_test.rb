require "test_helper"

class Card::NavigationTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "orders the whole column with golden cards first and excludes other states" do
    column = columns(:writebook_triage)
    cards(:logo).ungild
    cards(:layout).gild
    cards(:logo).update! last_active_at: 1.minute.from_now

    navigation = Card::Navigation.new(cards(:logo))
    assert_equal [ cards(:layout).number, cards(:logo).number ], navigation.numbers
    assert_equal column.id, navigation.column_id
    assert_equal column.name, navigation.name
  end

  test "includes cards beyond the board's first page without preloading their content" do
    board = boards(:writebook)
    60.times do |i|
      board.cards.create!(title: "Card #{i}", column: columns(:writebook_triage), status: :published)
    end

    assert_equal 62, Card::Navigation.new(cards(:logo)).numbers.size
  end

  test "maybe remains the original scope after the current card is moved" do
    card = cards(:buy_domain)
    other = card.board.cards.create!(title: "Another maybe", status: :published)
    card.triage_into columns(:writebook_triage)

    navigation = Card::Navigation.new(card, column_id: "maybe")
    assert_equal [ other.number ], navigation.numbers
    assert_equal "maybe", navigation.column_id
  end

  test "a column from another board is rejected" do
    column = boards(:private).columns.create!(name: "Private")
    assert_raises(ActiveRecord::RecordNotFound) do
      Card::Navigation.new(cards(:logo), column_id: column.id)
    end
  end
end
