class Cards::PublishesController < ApplicationController
  include CardScoped

  def create
    @card.publish

    respond_to do |format|
      format.html do
        if add_another_param?
          card = @board.cards.create!(status: :drafted)
          redirect_to card_draft_path(card), notice: "Card added"
        else
          redirect_to @card.board
        end
      end
      format.json { head :no_content }
    end
  end

  private
    def add_another_param?
      params[:creation_type] == "add_another"
    end
end
