class Boards::EntropiesController < ApplicationController
  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def update
    @board.update!(entropy_params)

    respond_to do |format|
      format.turbo_stream
      format.json { render "boards/show", status: :ok }
    end
  end

  private
    def entropy_params
      params.expect(board: [ :auto_postpone_period ])
    end
end
