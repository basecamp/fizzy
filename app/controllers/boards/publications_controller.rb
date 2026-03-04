class Boards::PublicationsController < ApplicationController
  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def create
    @board.publish

    respond_to do |format|
      format.turbo_stream
      format.json { render partial: "boards/board", locals: { board: @board }, status: :created }
    end
  end

  def destroy
    @board.unpublish
    @board.reload

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end
end
