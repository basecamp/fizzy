class Cards::SelfAssignmentsController < ApplicationController
  include CardScoped

  def create
    if @card.toggle_assignment(Current.user)
      respond_to do |format|
        format.turbo_stream { render "cards/assignments/create" }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.turbo_stream { render "cards/assignments/create" }
        format.json { head :unprocessable_entity }
      end
    end
  end
end
