class Cards::ImagesController < ApplicationController
  include CardScoped

  def destroy
    @card.image.purge_later

    respond_to do |format|
      format.html { redirect_to @card }
      format.json { head :no_content }
    end
  end
end
