class Prompts::Boards::UsersController < ApplicationController
  include BoardScoped

  def index
    @users = @board.users.active.alphabetically

    if stale? etag: @users
      render layout: false
    end
  end
end
