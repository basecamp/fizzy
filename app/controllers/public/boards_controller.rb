class Public::BoardsController < Public::BaseController
  def show
    cards = if @board.manual_sorting_enabled?
      @board.cards.awaiting_triage.with_golden_first.ordered_by_position(last_active_at: :desc, id: :desc)
    else
      @board.cards.awaiting_triage.latest.with_golden_first
    end
    set_page_and_extract_portion_from cards
  end
end
