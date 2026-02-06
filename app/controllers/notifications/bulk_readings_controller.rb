class Notifications::BulkReadingsController < ApplicationController
  def create
    Current.user.notifications.unread.read_all

    respond_to do |format|
      format.html do
        if from_tray?
          head :ok
        else
          redirect_to notifications_path
        end
      end
      format.json { head :no_content }
    end
  end

  private
    def from_tray?
      params[:from_tray]
    end
end
