class NotificationsController < ApplicationController
  def index
    @unread = Current.user.notifications.unread.ordered unless current_page_param
    set_page_and_extract_portion_from Current.user.notifications.read.ordered

    respond_to do |format|
      format.turbo_stream if current_page_param # Allows read-all action to side step pagination
      format.html
    end
  end
end
