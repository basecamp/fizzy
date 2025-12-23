class Public::Boards::Columns::NotNowsController < Public::BaseController
  def show
    cards = if @board.manual_sorting_enabled?
      @board.cards.postponed.ordered_by_position(last_active_at: :desc, id: :desc)
    else
      @board.cards.postponed.latest
    end
    set_page_and_extract_portion_from cards
  end
end
