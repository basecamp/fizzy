class Boards::Columns::ClosedsController < ApplicationController
  include BoardScoped

  def show
    cards = if @board.manual_sorting_enabled?
      @board.cards.closed.ordered_by_position(Arel.sql("closures.created_at DESC, cards.id DESC")).preloaded
    else
      @board.cards.closed.recently_closed_first.preloaded
    end
    set_page_and_extract_portion_from cards
    fresh_when etag: @page.records
  end
end
