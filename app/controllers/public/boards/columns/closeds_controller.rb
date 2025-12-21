class Public::Boards::Columns::ClosedsController < Public::BaseController
  def show
    set_page_and_extract_portion_from \
      @board.cards.closed.ordered_by_position(Arel.sql("closures.created_at DESC, cards.id DESC"))
  end
end
