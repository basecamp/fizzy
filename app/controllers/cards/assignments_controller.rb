class Bubbles::AssignmentsController < ApplicationController
  include BubbleScoped

  def new
  end

  def create
    @bubble.toggle_assignment @bucket.users.active.find(params[:assignee_id])
  end
end
