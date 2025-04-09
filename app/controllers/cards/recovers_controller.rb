class Cards::RecoversController < ApplicationController
  include CardScoped

  def create
    redirect_to @card.recover_abandoned_creation
  end
end
