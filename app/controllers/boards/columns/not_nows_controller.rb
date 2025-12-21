class Boards::Columns::NotNowsController < ApplicationController
  include BoardScoped

  def show
    cards = if @board.manual_sorting_enabled?
      @board.cards.postponed.ordered_by_position(last_active_at: :desc, id: :desc).preloaded
    else
      @board.cards.postponed.latest.preloaded
    end
    set_page_and_extract_portion_from cards
    fresh_when etag: @page.records
  end
end
