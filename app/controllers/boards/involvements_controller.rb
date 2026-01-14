class Boards::InvolvementsController < ApplicationController
  include BoardScoped

  def update
    @board.access_for(Current.user).update!(involvement: params[:involvement])
    respond_to do |format|
      format.html
      format.turbo_stream
      format.json { head :no_content }
    end
  end
end
