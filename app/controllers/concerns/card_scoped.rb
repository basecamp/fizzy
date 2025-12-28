# rbs_inline: enabled

module CardScoped
  extend ActiveSupport::Concern

  # @type self: singleton(ApplicationController) & singleton(CardScoped)

  # @rbs!
  #   @board: Board
  #   @card: Card

  included do
    before_action :set_card, :set_board
  end

  private
    def set_card
      # @type self: ApplicationController & CardScoped
      @card = Current.user.accessible_cards.find_by!(number: params[:card_id])
    end

    def set_board
      @board = @card.board
    end

    def render_card_replacement
      # @type self: ApplicationController & CardScoped
      render turbo_stream: turbo_stream.replace([ @card, :card_container ], partial: "cards/container", method: :morph, locals: { card: @card.reload })
    end
end
