class Cards::WatchesController < ApplicationController
  include CardScoped

  def create
    @card.watch_by Current.user
  end

  def destroy
    @card.unwatch_by Current.user
  end
end
