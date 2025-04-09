class Cards::AssignmentsController < ApplicationController
  include CardScoped

  def new
  end

  def create
    @card.toggle_assignment @collection.users.active.find(params[:assignee_id])
  end
end
