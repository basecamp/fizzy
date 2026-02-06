module CardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_card, :set_board
  end

  private
    def set_card
      @card = Current.user.accessible_cards.find_by!(number: params[:card_id])
    end

    def set_board
      @board = @card.board
    end

    def render_card_replacement
      render turbo_stream: turbo_stream.replace([ @card, :card_container ], partial: "cards/container", method: :morph, locals: { card: @card.reload })
    end

    def capture_card_location
      @source_column = @card.column
      @was_in_stream = @card.awaiting_triage?
    end

    def refresh_stream_if_needed
      if @was_in_stream
        set_page_and_extract_portion_from @board.cards.awaiting_triage.latest.with_golden_first.preloaded
      end
    end
end
