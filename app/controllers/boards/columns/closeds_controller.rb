class Boards::Columns::ClosedsController < ApplicationController
  include BoardScoped

  def show
    set_page_and_extract_portion_from \
      @board.cards.closed.ordered_by_position(Arel.sql("closures.created_at DESC, cards.id DESC")).preloaded
    fresh_when etag: @page.records
  end
end
