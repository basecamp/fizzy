class Cards::TriagesController < ApplicationController
  include CardScoped

  def create
    column = @card.collection.columns.find(params[:column_id])
    @card.triage_into(column)

    redirect_to @card
  end

  def destroy
    @card.send_back_to_triage
    redirect_to @card
  end
end
