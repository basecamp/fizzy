class Columns::Cards::Drops::NotNowsController < ApplicationController
  include CardScoped

  def create
    ActiveRecord::Base.transaction do
      @card.postpone unless @card.postponed?

      Card::Positioner
        .new(relation: @board.cards.postponed, fallback_order: { last_active_at: :desc, id: :desc })
        .reposition!(card: @card, before_number: params[:before_id], after_number: params[:after_id])
    end
  end
end
