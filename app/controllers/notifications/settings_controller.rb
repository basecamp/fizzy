class Notifications::SettingsController < ApplicationController
  wrap_parameters :user_settings, include: %i[ bundle_email_frequency ]

  before_action :set_settings

  def show
    @boards = Current.user.boards.alphabetically
  end

  def update
    @settings.update!(settings_params)

    respond_to do |format|
      format.html { redirect_to notifications_settings_path, notice: "Settings updated" }
      format.json { head :no_content }
    end
  end

  private
    def set_settings
      @settings = Current.user.settings
    end

    def settings_params
      params.expect(user_settings: :bundle_email_frequency)
    end
end
