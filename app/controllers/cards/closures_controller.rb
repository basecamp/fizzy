class Bubbles::PopsController < ApplicationController
  include BubbleScoped

  def create
    @bubble.pop!(user: Current.user, reason: params[:reason])
    redirect_to @bubble
  end

  def destroy
    @bubble.unpop
    redirect_to @bubble
  end
end
