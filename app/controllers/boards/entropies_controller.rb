class Boards::EntropiesController < ApplicationController
  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def update
    @board.entropy.update!(entropy_params)
  end

  private
    def entropy_params
      params.expect(board: [ :auto_postpone_period ])
    end
end
