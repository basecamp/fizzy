class Account::ArchivedBoardsController < ApplicationController
  def index
    @boards = Current.user.boards.archived.alphabetically.includes(:creator, archival: :user)
  end
end
