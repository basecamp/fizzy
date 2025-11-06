class Boards::PublicationsController < ApplicationController
  include BoardScoped

  def create
    @board.publish
  end

  def destroy
    @board.unpublish
    @board.reload
  end
end
