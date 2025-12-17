class Cards::NotNowsController < ApplicationController
  include CardScoped

  def create
    @card.postpone

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end
end
