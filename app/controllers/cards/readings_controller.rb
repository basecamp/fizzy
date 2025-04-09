class Cards::ReadingsController < ApplicationController
  include CardScoped

  def create
    mark_card_notifications_read
    @notifications = Current.user.notifications.unread.ordered.limit(20)
  end

  private
    def mark_card_notifications_read
      Current.user.notifications.unread.where(card: @card).read_all
    end
end
