class Boards::EntropiesController < ApplicationController
  include BoardScoped

  def update
    @board.entropy.update!(entropy_params)
  end

  private
    def entropy_params
      params.expect(board: [ :auto_postpone_period ])
    end
end
