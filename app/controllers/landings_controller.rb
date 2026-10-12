class LandingsController < ApplicationController
  def show
    flash.keep(:welcome_letter)

    if Current.user.boards.active.one?
      redirect_to board_path(Current.user.boards.active.first)
    else
      redirect_to root_path
    end
  end
end
