class Columns::Cards::Drops::ClosuresController < ApplicationController
  include CardScoped

  def create
    ActiveRecord::Base.transaction do
      @card.close

      Card::Positioner
        .new(relation: @board.cards.closed, fallback_order: Arel.sql("closures.created_at DESC, cards.id DESC"))
        .reposition!(card: @card, before_number: params[:before_id], after_number: params[:after_id])
    end
  end
end
