class Cards::BubbleUpsController < ApplicationController
  include CardScoped

  def create
    @card.bubble_up_at TimeSlot.for(params[:slot])

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end

  def destroy
    @card.pop

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end
end
