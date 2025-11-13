class Cards::AssignmentsController < ApplicationController
  include CardScoped

  def new
    @users = @board.users.active.alphabetically
    fresh_when etag: [ @users, @card.assignees ]
  end

  def create
    @card.toggle_assignment @board.users.active.find(params[:assignee_id])
  end
end
