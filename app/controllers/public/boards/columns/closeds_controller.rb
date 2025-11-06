class Public::Boards::Columns::ClosedsController < Public::BaseController
  def show
    set_page_and_extract_portion_from @board.cards.closed.recently_closed_first
  end
end
