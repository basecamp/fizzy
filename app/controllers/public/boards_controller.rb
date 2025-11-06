class Public::BoardsController < Public::BaseController
  def show
    set_page_and_extract_portion_from @board.cards.awaiting_triage.latest.with_golden_first
  end
end
