class Columns::Cards::Drops::ColumnsController < ApplicationController
  include CardScoped

  def create
    @column = @card.board.columns.find(params[:column_id])

    ActiveRecord::Base.transaction do
      already_in_target = @card.active? && @card.column == @column

      if already_in_target
        return unless @board.manual_sorting_enabled?
      else
        @card.triage_into(@column)
      end

      relation = @column.cards.active
      relation = if @card.golden?
        relation.joins(:goldness)
      else
        relation.where.missing(:goldness)
      end

      before_id = @board.manual_sorting_enabled? ? params[:before_id] : nil
      after_id = @board.manual_sorting_enabled? ? params[:after_id] : nil

      Card::Positioner
        .new(relation: relation, fallback_order: { last_active_at: :desc, id: :desc })
        .reposition!(card: @card, before_number: before_id, after_number: after_id)
    end
  end
end
