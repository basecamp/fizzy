class Cards::WatchesController < ApplicationController
  include CardScoped

  def show
    fresh_when etag: @card.watch_for(Current.user) || "none"
  end

  def create
    @card.watch_by Current.user

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def destroy
    @card.unwatch_by Current.user

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end
end
