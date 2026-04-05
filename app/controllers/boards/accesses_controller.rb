class Boards::AccessesController < ApplicationController
  include BoardScoped

  def index
    @users = @board.account.users.active.alphabetically.includes(:identity)
  end

  private
    def involvement_by_user
      @involvement_by_user ||= @board.accesses.pluck(:user_id, :involvement).to_h
    end

    helper_method :involvement_by_user
end
