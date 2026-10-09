class Cards::BoardsController < ApplicationController
  include BoardScoped

  skip_before_action :set_board, only: %i[ edit ]
  before_action :set_card
  before_action :ensure_card_board_is_active, only: %i[ update ]

  def edit
    @boards = Current.user.boards.active.ordered_by_recently_accessed
    fresh_when @boards
  end

  def update
    @card.move_to(@board)

    respond_to do |format|
      format.html { redirect_to @card }
      format.json { render "cards/show" }
    end
  end

  private
    def set_card
      @card = Current.user.accessible_cards.find_by!(number: params[:card_id])
    end

    def ensure_card_board_is_active
      if @card.board.archived?
        head :forbidden
      end
    end
end
