class Public::BoardsController < Public::BaseController
  def show
    set_page_and_extract_portion_from \
      @board.cards.awaiting_triage.with_golden_first.ordered_by_position(last_active_at: :desc, id: :desc)
  end
end
