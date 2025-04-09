class Cards::ClosuresController < ApplicationController
  include CardScoped

  def create
    @card.closure!(user: Current.user, reason: params[:reason])
    redirect_to @card
  end

  def destroy
    @card.unpop
    redirect_to @card
  end
end
