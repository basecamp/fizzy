class Cards::NotNowsController < ApplicationController
  include CardScoped

  def create
    ActiveRecord::Base.transaction do
      @card.postpone

      Card::Positioner
        .new(relation: @board.cards.postponed, fallback_order: { last_active_at: :desc, id: :desc })
        .reposition!(card: @card, before_number: nil, after_number: nil)
    end

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end
end
