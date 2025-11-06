class Columns::Cards::Drops::StreamsController < ApplicationController
  include CardScoped

  def create
    @card.send_back_to_triage
    set_page_and_extract_portion_from @board.cards.awaiting_triage.latest.with_golden_first
  end
end
