class Bubbles::ReadingsController < ApplicationController
  include BubbleScoped

  def create
    mark_bubble_notifications_read
    @notifications = Current.user.notifications.unread.ordered.limit(20)
  end

  private
    def mark_bubble_notifications_read
      Current.user.notifications.unread.where(bubble: @bubble).read_all
    end
end
