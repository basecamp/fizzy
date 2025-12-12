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

    respond_to do |format|
      format.html { redirect_to @card }
      format.json { head :no_content }
    end
  end

  private
    def set_card
      @card = Current.user.accessible_cards.find_by!(number: params[:card_id])
    end
end
