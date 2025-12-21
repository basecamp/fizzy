class Columns::Cards::Drops::ColumnsController < ApplicationController
  include CardScoped

  def create
    @column = @card.board.columns.find(params[:column_id])

    ActiveRecord::Base.transaction do
      @card.triage_into(@column) unless @card.active? && @card.column == @column

      relation = @column.cards.active
      relation = if @card.golden?
        relation.joins(:goldness)
      else
        relation.where.missing(:goldness)
      end

      Card::Positioner
        .new(relation: relation, fallback_order: { last_active_at: :desc, id: :desc })
        .reposition!(card: @card, before_number: params[:before_id], after_number: params[:after_id])
    end
  end
end
