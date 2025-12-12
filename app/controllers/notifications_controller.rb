class NotificationsController < ApplicationController
  MAX_UNREAD_NOTIFICATIONS = 500
  MAX_UNREAD_NOTIFICATIONS_VIA_API = 100

  def index
    @unread = Current.user.notifications.unread.ordered.preloaded.limit(max_unread_notifications) unless current_page_param
    set_page_and_extract_portion_from Current.user.notifications.read.ordered.preloaded

    respond_to do |format|
      format.turbo_stream if current_page_param # Allows read-all action to side step pagination
      format.html
      format.json
    end
  end

  private
    def max_unread_notifications
      request.format.json? ? MAX_UNREAD_NOTIFICATIONS_VIA_API : MAX_UNREAD_NOTIFICATIONS
    end
end
