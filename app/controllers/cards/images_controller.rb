class Cards::ImagesController < ApplicationController
  include CardScoped

  def destroy
    @card.image.purge_later
    redirect_to @card
  end
end
