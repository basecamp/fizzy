class Notifications::ReadingsController < ApplicationController
  def create
    @notification = Current.user.notifications.find(params[:notification_id])
    @notification.read

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def destroy
    @notification = Current.user.notifications.find(params[:notification_id])
    @notification.unread

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end
end
