class Boards::Columns::NotNowsController < ApplicationController
  include BoardScoped

  def show
    set_page_and_extract_portion_from \
      @board.cards.postponed.ordered_by_position(last_active_at: :desc, id: :desc).preloaded
    fresh_when etag: @page.records
  end
end
