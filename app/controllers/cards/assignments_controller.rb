class Cards::AssignmentsController < ApplicationController
  include CardScoped

  def new
    @users = @collection.users.active.alphabetically
    fresh_when @users
  end

  def create
    @card.toggle_assignment @collection.users.active.find(params[:assignee_id])
  end
end
