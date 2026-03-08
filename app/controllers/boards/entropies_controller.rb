class Boards::EntropiesController < ApplicationController
  wrap_parameters :board

  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def update
    @board.update!(entropy_params)

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private
    def entropy_params
      params.expect(board: [ :auto_postpone_period ])
    end
end
