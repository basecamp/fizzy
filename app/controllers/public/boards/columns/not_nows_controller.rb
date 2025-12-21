class Public::Boards::Columns::NotNowsController < Public::BaseController
  def show
    set_page_and_extract_portion_from \
      @board.cards.postponed.ordered_by_position(last_active_at: :desc, id: :desc)
  end
end
