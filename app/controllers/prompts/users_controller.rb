class Prompts::UsersController < ApplicationController
  def index
    @users = User.active.alphabetically

    if stale? etag: @users
      render layout: false
    end
  end
end
