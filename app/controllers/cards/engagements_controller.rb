class Bubbles::EngagementsController < ApplicationController
  include BubbleScoped

  def create
    @bubble.engage
    redirect_to @bubble
  end

  def destroy
    @bubble.reconsider
    redirect_to @bubble
  end
end
