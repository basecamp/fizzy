module CardTestHelper
  def assert_card_container_rerendered(card)
    assert_turbo_stream action: :replace, target: dom_id(card, :card_container)
  end

  # A card that leaves a full page keeps the page count and newest timestamp.
  def create_full_page_of_cards(board, **attributes)
    Current.set(session: sessions(:kevin)) do
      20.times.map do |index|
        card = board.cards.create!(title: "Card #{index}", status: "published", **attributes)
        yield card if block_given?
        card.tap { it.update_columns(last_active_at: index.minutes.ago, updated_at: index.hours.ago) }
      end
    end
  end
end
