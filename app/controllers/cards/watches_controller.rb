class Cards::WatchesController < ApplicationController
  include CardScoped

  def show
    fresh_when etag: @card.watch_for(Current.user) || "none"
  end

  def create
    @card.watch_by Current.user
  end

  def destroy
    @card.unwatch_by Current.user
  end
end
