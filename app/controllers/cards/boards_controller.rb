class Cards::BoardsController < ApplicationController
  include BoardScoped

  skip_before_action :set_board, only: %i[ edit ]
  before_action :set_card

  def edit
    @boards = Current.user.boards.ordered_by_recently_accessed
    fresh_when @boards
  end

  def update
    @card.move_to(@board)
    redirect_to @card
  end

  private
    def set_card
      @card = Current.user.accessible_cards.find(params[:card_id])
    end
end
