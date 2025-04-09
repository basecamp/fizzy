class Cards::PublishesController < ApplicationController
  include CardScoped

  def create
    @card.publish
    redirect_to @card
  end
end
