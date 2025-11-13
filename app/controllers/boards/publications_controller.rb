class Boards::PublicationsController < ApplicationController
  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def create
    @board.publish
  end

  def destroy
    @board.unpublish
    @board.reload
  end
end
