class Cards::ClosuresController < ApplicationController
  include CardScoped

  def create
    @card.close(user: Current.user, reason: params[:reason])
    redirect_to @card
  end

  def destroy
    @card.reopen
    redirect_to @card
  end
end
