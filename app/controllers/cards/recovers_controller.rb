class Bubbles::RecoversController < ApplicationController
  include BubbleScoped

  def create
    redirect_to @bubble.recover_abandoned_creation
  end
end
