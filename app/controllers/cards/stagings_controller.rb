class Bubbles::StagingsController < ApplicationController
  include BubbleScoped

  def create
    if params[:stage_id].present?
      @bubble.toggle_stage Current.account.stages.find(params[:stage_id])
    else
      @bubble.update!(stage: nil)
    end
  end
end
