class Bubbles::WatchesController < ApplicationController
  include BubbleScoped

  def create
    @bubble.watch_by Current.user
    redirect_to bubble_watch_path(@bubble)
  end

  def destroy
    @bubble.unwatch_by Current.user
    redirect_to bubble_watch_path(@bubble)
  end
end
