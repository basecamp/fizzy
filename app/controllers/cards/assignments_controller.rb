# rbs_inline: enabled

module Cards
  class AssignmentsController < ApplicationController
    include CardScoped

    def new
      @assigned_to = @card.assignees.active.alphabetically.where.not(id: Current.user)
      @users = @board.users.active.alphabetically.where.not(id: @card.assignees).where.not(id: Current.user)
      fresh_when etag: [ @users, @card.assignees ]
    end

    def create
      @card.toggle_assignment @board.users.active.find(params[:assignee_id])
    end
  end
end
