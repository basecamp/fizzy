class Boards::Columns::NotNowsController < ApplicationController
  include BoardScoped

  def show
    set_page_and_extract_portion_from @board.cards.postponed.reverse_chronologically.with_golden_first
    fresh_when etag: @page.records
  end
end
