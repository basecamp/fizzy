class My::MenusController < ApplicationController
  def show
    @filters = Current.user.filters.all.load_async
    @boards = Current.user.boards.ordered_by_recently_accessed.load_async
    @tags = Tag.all.alphabetically.load_async
    @users = User.active.alphabetically.load_async

    fresh_when etag: [ @filters, @boards.pluck(:name), @tags, @users ] # Boards are touched when cards change, so we pick the names
  end
end
