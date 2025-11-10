class My::MenusController < ApplicationController
  def show
    @filters = Current.user.filters.all
    @boards = Current.user.boards.ordered_by_recently_accessed
    @tags = Tag.all.alphabetically
    @users = User.active.alphabetically

    # fresh_when etag: [ @user_filtering, Current.session ]
  end
end
