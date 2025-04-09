class Cards::WatchesController < ApplicationController
  include CardScoped

  def create
    @card.watch_by Current.user
    redirect_to card_watch_path(@card)
  end

  def destroy
    @card.unwatch_by Current.user
    redirect_to card_watch_path(@card)
  end
end
