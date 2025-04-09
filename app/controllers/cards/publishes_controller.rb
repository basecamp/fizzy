class Bubbles::PublishesController < ApplicationController
  include BubbleScoped

  def create
    @bubble.publish
    redirect_to @bubble
  end
end
