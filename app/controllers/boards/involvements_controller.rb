class Boards::InvolvementsController < ApplicationController
  include BoardScoped

  def update
    @board.access_for(Current.user).update!(involvement: params[:involvement])
  end
end
