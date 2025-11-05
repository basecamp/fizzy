class LandingsController < ApplicationController
  def show
    if Current.user.collections.one?
      redirect_to collection_path(Current.user.collections.first)
    else
      redirect_to events_path
    end
  end
end
