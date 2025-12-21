class Cards::TriagesController < ApplicationController
  include CardScoped

  def create
    column = @card.board.columns.find(params[:column_id])
    ActiveRecord::Base.transaction do
      @card.triage_into(column)

      relation = column.cards.active
      relation = if @card.golden?
        relation.joins(:goldness)
      else
        relation.where.missing(:goldness)
      end

      Card::Positioner
        .new(relation: relation, fallback_order: { last_active_at: :desc, id: :desc })
        .reposition!(card: @card, before_number: nil, after_number: nil)
    end

    respond_to do |format|
      format.html { redirect_to @card }
      format.json { head :no_content }
    end
  end

  def destroy
    ActiveRecord::Base.transaction do
      @card.send_back_to_triage

      relation = @board.cards.awaiting_triage
      relation = if @card.golden?
        relation.joins(:goldness)
      else
        relation.where.missing(:goldness)
      end

      Card::Positioner
        .new(relation: relation, fallback_order: { last_active_at: :desc, id: :desc })
        .reposition!(card: @card, before_number: nil, after_number: nil)
    end

    respond_to do |format|
      format.html { redirect_to @card }
      format.json { head :no_content }
    end
  end
end
