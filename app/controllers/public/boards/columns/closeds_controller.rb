class Public::Boards::Columns::ClosedsController < Public::BaseController
  def show
    cards = if @board.manual_sorting_enabled?
      @board.cards.closed.ordered_by_position(Arel.sql("closures.created_at DESC, cards.id DESC"))
    else
      @board.cards.closed.recently_closed_first
    end
    set_page_and_extract_portion_from cards
  end
end
