class Boards::PublicationsController < ApplicationController
  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def create
    @board.publish
    respond_to do |format|
      format.html
      format.turbo_stream
      format.json { render json: { key: @board.publication.key, url: published_board_url(@board) } }
    end
  end

  def destroy
    @board.unpublish
    @board.reload
    respond_to do |format|
      format.html
      format.turbo_stream
      format.json { head :no_content }
    end
  end
end
