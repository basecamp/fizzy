class Public::BaseController < ApplicationController
  allow_unauthenticated_access

  before_action :set_board, :set_card, :set_public_cache_expiration
  before_action :ensure_board_accessible

  layout "public"

  private
    def set_board
      @board = Board.find_by_published_key(params[:board_id] || params[:id])
    end

    def set_card
      @card = @board.cards.published.find_by!(number: params[:id]) if params[:board_id] && params[:id]
    end

    def set_public_cache_expiration
      expires_in 30.seconds, public: true
    end

    def ensure_board_accessible
      raise ActionController::RoutingError, "Not Found" if @board&.account&.cancelled?
    end
end
