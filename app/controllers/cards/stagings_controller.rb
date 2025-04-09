class Cards::StagingsController < ApplicationController
  include CardScoped

  def create
    if params[:stage_id].present?
      @card.toggle_stage Current.account.stages.find(params[:stage_id])
    else
      @card.update!(stage: nil)
    end
  end
end
