class Cards::PublishesController < ApplicationController
  include CardScoped

  def create
    ActiveRecord::Base.transaction do
      @card.publish

      relation = if @card.triaged?
        @card.column.cards.active
      else
        @board.cards.awaiting_triage
      end

      relation = if @card.golden?
        relation.joins(:goldness)
      else
        relation.where.missing(:goldness)
      end

      Card::Positioner
        .new(relation: relation, fallback_order: { last_active_at: :desc, id: :desc })
        .reposition!(card: @card, before_number: nil, after_number: nil)
    end

    if add_another_param?
      redirect_to @board.cards.create!, notice: "Card added"
    else
      redirect_to @card.board
    end
  end

  private
    def add_another_param?
      params[:creation_type] == "add_another"
    end
end
