class Boards::Columns::StreamsController < ApplicationController
  include BoardScoped

  def show
    set_page_and_extract_portion_from @board.cards.awaiting_triage.latest.with_golden_first.preloaded
    fresh_when etag: [ @board, @page.records ]
  end
end
