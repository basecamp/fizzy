class Boards::BurndownsController < ApplicationController
  include BoardScoped

  def show
    unless @board.sprint_configured?
      redirect_to edit_board_path(@board), alert: "Please configure sprint settings first"
      return
    end

    @burndown = @board.burndown_data
  end
end
