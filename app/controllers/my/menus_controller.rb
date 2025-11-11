class My::MenusController < ApplicationController
  def show
    @filters = Current.user.filters.all.load_async
    @boards = Current.user.boards.ordered_by_recently_accessed.load_async
    @tags = Tag.all.alphabetically.load_async
    @users = User.active.alphabetically.load_async

    fresh_when etag: [ @filters, @boards.pluck(:id), @tags, @users ]
  end
end
