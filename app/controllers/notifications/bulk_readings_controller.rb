class Notifications::BulkReadingsController < ApplicationController
  def create
    Current.user.notifications.unread.read_all

    if from_tray?
      head :ok
    else
      redirect_to notifications_path
    end
  end

  private
    def from_tray?
      params[:from_tray]
    end
end
