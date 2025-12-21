class Cards::ClosuresController < ApplicationController
  include CardScoped

  def create
    ActiveRecord::Base.transaction do
      @card.close

      Card::Positioner
        .new(relation: @board.cards.closed, fallback_order: Arel.sql("closures.created_at DESC, cards.id DESC"))
        .reposition!(card: @card, before_number: nil, after_number: nil)
    end

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end

  def destroy
    ActiveRecord::Base.transaction do
      @card.reopen

      relation = if @card.postponed?
        @board.cards.postponed
      elsif @card.triaged?
        @card.column.cards.active
      else
        @board.cards.awaiting_triage
      end

      if @card.active?
        relation = if @card.golden?
          relation.joins(:goldness)
        else
          relation.where.missing(:goldness)
        end
      end

      Card::Positioner
        .new(relation: relation, fallback_order: { last_active_at: :desc, id: :desc })
        .reposition!(card: @card, before_number: nil, after_number: nil)
    end

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end
end
