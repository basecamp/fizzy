class Boards::ArchivalsController < ApplicationController
  include BoardScoped

  skip_before_action :ensure_board_is_active
  before_action :ensure_permission_to_admin_board

  def create
    @board.archive

    respond_to do |format|
      format.html { redirect_to @board, notice: "Board archived" }
      format.json { render partial: "boards/board", locals: { board: @board }, status: :created }
    end
  end

  def destroy
    @board.unarchive

    respond_to do |format|
      format.html { redirect_back_or_to @board, notice: "Board unarchived" }
      format.json { head :no_content }
    end
  end
end
