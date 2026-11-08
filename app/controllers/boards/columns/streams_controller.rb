class Boards::Columns::StreamsController < ApplicationController
  include BoardScoped, ColumnFiltering

  def show
    set_page_and_extract_portion_from filtered(@board.cards.awaiting_triage.latest.with_golden_first.preloaded)
    fresh_when etag: @page.records
  end
end
