class Prompts::Boards::UsersController < ApplicationController
  include BoardScoped

  def index
    @users = @board.users.alphabetically

    if stale? etag: @users
      render layout: false
    end
  end
end
