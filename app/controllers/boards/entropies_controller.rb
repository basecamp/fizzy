class Boards::EntropiesController < ApplicationController
  wrap_parameters :board, include: [ :auto_postpone_period_in_days ]

  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def update
    @board.update!(entropy_params)

    respond_to do |format|
      format.turbo_stream
      format.json { render "boards/show", status: :ok }
    end
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  private
    def entropy_params
      params.expect(board: [ :auto_postpone_period_in_days ])
    end
end
