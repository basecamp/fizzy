class Columns::Cards::Drops::ClosuresController < ApplicationController
  include CardScoped

  def create
    if @card.closed?
      return unless @board.manual_sorting_enabled?
    else
      @card.close
    end

    before_id = @board.manual_sorting_enabled? ? params[:before_id] : nil
    after_id = @board.manual_sorting_enabled? ? params[:after_id] : nil

    Card::Positioner
      .new(relation: @board.cards.closed, fallback_order: Arel.sql("closures.created_at DESC, cards.id DESC"))
      .reposition!(card: @card, before_number: before_id, after_number: after_id)
  end
end
