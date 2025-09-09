class Cards::AssignmentsController < ApplicationController
  include CardScoped

  def new
  end

  def create
    @card.toggle_assignment @collection.users.active.find(params[:assignee_id])

    render turbo_stream: turbo_stream.replace([ @card, :assignees ], partial: "cards/display/perma/assignees", locals: { card: @card.reload })
  end
end
