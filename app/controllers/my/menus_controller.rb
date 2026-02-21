class My::MenusController < ApplicationController
  def show
    @filters = Current.user.filters.all
    @boards = Current.user.boards.ordered_by_recently_accessed.includes(columns: :cards)
    @tags = Current.account.tags.all.alphabetically
    @users = Current.account.users.active.alphabetically
    @accounts = Current.identity.accounts.active

    fresh_when etag: [ @filters, @boards, @tags, @users, @accounts ]
  end
end
