class Columns::Cards::Drops::NotNowsController < ApplicationController
  include CardScoped

  def create
    ActiveRecord::Base.transaction do
      if @card.postponed?
        return unless @board.manual_sorting_enabled?
      else
        @card.postpone
      end

      before_id = @board.manual_sorting_enabled? ? params[:before_id] : nil
      after_id = @board.manual_sorting_enabled? ? params[:after_id] : nil

      Card::Positioner
        .new(relation: @board.cards.postponed, fallback_order: { last_active_at: :desc, id: :desc })
        .reposition!(card: @card, before_number: before_id, after_number: after_id)
    end
  end
end
