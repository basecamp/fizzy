class Boards::Columns::StreamsController < ApplicationController
  include BoardScoped

  def show
    cards = if @board.manual_sorting_enabled?
      @board.cards.awaiting_triage.with_golden_first.ordered_by_position(last_active_at: :desc, id: :desc).preloaded
    else
      @board.cards.awaiting_triage.latest.with_golden_first.preloaded
    end
    set_page_and_extract_portion_from cards
    fresh_when etag: @page.records
  end
end
