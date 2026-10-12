class Boards::InvolvementsController < ApplicationController
  include BoardScoped

  skip_before_action :ensure_board_is_active

  def update
    @board.access_for(Current.user).update!(involvement: params[:involvement])

    respond_to do |format|
      format.html
      format.turbo_stream
      format.json { head :no_content }
    end
  end
end
