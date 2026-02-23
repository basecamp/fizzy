class Boards::Columns::ClosedsController < ApplicationController
  include BoardScoped
  include FilterScoped

  def show
    set_page_and_extract_portion_from @board.cards.closed.recently_closed_first.preloaded
    fresh_when etag: @page.records
  end
end
