class Columns::Cards::Drops::StreamsController < ApplicationController
  include CardScoped

  def create
    ActiveRecord::Base.transaction do
      @card.send_back_to_triage unless @card.awaiting_triage?

      relation = @board.cards.awaiting_triage
      relation = if @card.golden?
        relation.joins(:goldness)
      else
        relation.where.missing(:goldness)
      end

      Card::Positioner
        .new(relation: relation, fallback_order: { last_active_at: :desc, id: :desc })
        .reposition!(card: @card, before_number: params[:before_id], after_number: params[:after_id])
    end

    set_page_and_extract_portion_from @board.cards.awaiting_triage.with_golden_first.ordered_by_position(last_active_at: :desc, id: :desc)
  end
end
