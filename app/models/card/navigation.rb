class Card::Navigation
  attr_reader :card, :column

  def initialize(card, column_id: nil)
    @card = card
    @column = if column_id == "maybe"
      nil
    elsif column_id.present?
      card.board.columns.find(column_id)
    else
      card.column
    end
  end

  def numbers
    cards.latest.with_golden_first.pluck(:number)
  end

  def column_id
    column&.id || "maybe"
  end

  def name
    column&.name || "Maybe"
  end

  private
    def cards
      if column
        column.cards.active
      else
        card.board.cards.awaiting_triage
      end
    end
end
