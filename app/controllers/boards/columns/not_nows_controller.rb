class Boards::Columns::NotNowsController < ApplicationController
  include BoardScoped, ColumnFiltering

  def show
    set_page_and_extract_portion_from filtered(@board.cards.postponed.latest.preloaded)
    fresh_when etag: @page.records
  end
end
