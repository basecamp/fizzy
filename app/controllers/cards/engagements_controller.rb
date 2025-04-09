class Cards::EngagementsController < ApplicationController
  include CardScoped

  def create
    @card.engage
    redirect_to @card
  end

  def destroy
    @card.reconsider
    redirect_to @card
  end
end
