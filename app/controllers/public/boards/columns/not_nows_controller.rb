class Public::Boards::Columns::NotNowsController < Public::BaseController
  def show
    set_page_and_extract_portion_from @board.cards.postponed.latest
  end
end
