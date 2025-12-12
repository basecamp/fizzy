class Cards::GoldnessesController < ApplicationController
  include CardScoped

  def create
    @card.gild

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end

  def destroy
    @card.ungild

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end
end
